import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/offline/cache_controller.dart';

class CacheView<T> extends StatefulWidget {
  const CacheView({required this.controller, required this.builder, super.key});

  final CacheController<T> controller;
  final Widget Function(BuildContext, T) builder;

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
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      unawaited(controller.refresh());
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final elapsed = DateTime.now().toUtc().difference(cached.updatedAtUtc);

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
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: controller.refreshing
                            ? null
                            : () {
                                unawaited(controller.refresh());
                              },
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
