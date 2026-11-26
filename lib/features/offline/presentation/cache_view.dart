import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/offline/cache_controller.dart';

class CacheView<T> extends StatefulWidget {
  const new({
    required this.controller,
    required this.builder,
    this.clock,
    super.key,
  });

  final CacheController<T> controller;
  final Widget Function(BuildContext, T) builder;
  final DateTime Function()? clock;

  @override
  State<CacheView<T>> createState() => _CacheViewState<T>();
}

class _CacheViewState<T> extends State<CacheView<T>> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    _refreshAfterBuild();
  }

  @override
  void didUpdateWidget(covariant CacheView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      _refreshAfterBuild();
    }
  }

  void _refreshAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.controller.refresh());
      }
    });
  }

  void _retry() {
    unawaited(widget.controller.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final controller = widget.controller;
        final cached = controller.cached;
        final failure = controller.failure;

        if (cached == null) {
          if (failure == null) {
            return const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading data'),
            );
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(failure.message),
                    if (failure.correlationId case final reference?) ...[
                      const SizedBox(height: 8),
                      Text('Reference: $reference'),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: controller.refreshing ? null : _retry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final now = (widget.clock ?? DateTime.now)().toUtc();
        final elapsed = now.difference(cached.updatedAtUtc);
        final age = elapsed.isNegative
            ? 'The saved time is ahead of this device clock.'
            : 'Cached · ${elapsed.inMinutes} min old';
        final colors = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: failure == null
                  ? colors.secondaryContainer
                  : colors.errorContainer,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: failure == null
                      ? colors.onSecondaryContainer
                      : colors.onErrorContainer,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(age),
                      Text(
                        'Updated '
                        '${formatJohannesburgDate(cached.updatedAtUtc, includeTime: true)} SAST',
                      ),
                      if (failure != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          failure is OfflineFailure
                              ? 'Offline. Showing the saved copy.'
                              : 'Could not refresh. Showing the saved copy.',
                        ),
                        if (failure.correlationId case final reference?)
                          Text('Reference: $reference'),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: controller.refreshing ? null : _retry,
                          style: TextButton.styleFrom(
                            foregroundColor: failure == null
                                ? colors.onSecondaryContainer
                                : colors.onErrorContainer,
                          ),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            controller.refreshing ? 'Refreshing…' : 'Try again',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: widget.builder(context, cached.value),
              ),
            ),
          ],
        );
      },
    );
  }
}
