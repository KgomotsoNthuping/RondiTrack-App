import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/contributions/application/contribution_history_controller.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';

class ContributionHistoryList extends StatefulWidget {
  const new({
    required this.controller,
    required this.header,
    required this.onClearFilters,
    this.invalidFilters = false,
    super.key,
  });

  final ContributionHistoryController controller;
  final Widget header;
  final VoidCallback onClearFilters;
  final bool invalidFilters;

  @override
  State<ContributionHistoryList> createState() =>
      _ContributionHistoryListState();
}

class _ContributionHistoryListState extends State<ContributionHistoryList> {
  static const _headerKey = ValueKey('history-header');
  static const _footerKey = ValueKey('history-footer');

  final _tiles = <String, ContributionHistoryTile>{};
  Map<String, int> _indices = {};
  List<Contribution>? _snapshot;

  void _synchronise(List<Contribution> items) {
    if (identical(items, _snapshot)) {
      return;
    }

    _snapshot = items;

    final current = {for (final item in items) item.id: item};

    _tiles.removeWhere((id, tile) => current[id] != tile.item);

    _indices = {
      for (var index = 0; index < items.length; index++)
        items[index].id: index + 1,
    };
  }

  void _nearEnd(ScrollMetrics metrics) {
    if (!widget.invalidFilters &&
        metrics.extentAfter < 300 &&
        widget.controller.canLoadMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            !widget.invalidFilters &&
            widget.controller.canLoadMore) {
          unawaited(widget.controller.loadMore());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      child: widget.header,
      builder: (context, header) {
        final items = widget.invalidFilters
            ? const <Contribution>[]
            : controller.items;

        _synchronise(items);

        return NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) {
              _nearEnd(notification.metrics);
            }

            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) {
                _nearEnd(notification.metrics);
              }

              return false;
            },
            child: RefreshIndicator(
              onRefresh: widget.invalidFilters
                  ? () async {}
                  : controller.refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: items.length + 2,
                findChildIndexCallback: (key) {
                  if (key == _headerKey) {
                    return 0;
                  }

                  if (key == _footerKey) {
                    return items.length + 1;
                  }

                  return key is ValueKey<String> ? _indices[key.value] : null;
                },
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      key: _headerKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header!,
                        if (controller.refreshing)
                          const LinearProgressIndicator(),
                        if (controller.refreshFailure case final failure?) ...[
                          Text(failure.message),
                          TextButton(
                            onPressed: controller.refresh,
                            child: const Text('Retry refresh'),
                          ),
                        ],
                      ],
                    );
                  }

                  if (index == items.length + 1) {
                    return KeyedSubtree(
                      key: _footerKey,
                      child: _footer(items.isEmpty),
                    );
                  }

                  final item = items[index - 1];

                  return _tiles.putIfAbsent(
                    item.id,
                    () => ContributionHistoryTile(
                      key: ValueKey(item.id),
                      item: item,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _footer(bool empty) {
    final controller = widget.controller;

    if (widget.invalidFilters) {
      return Column(
        children: [
          const Text('These contribution filters are invalid.'),
          TextButton(
            onPressed: widget.onClearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      );
    }

    if (empty) {
      return switch (controller.phase) {
        HistoryPhase.initialLoading => const Column(
          children: [
            CircularProgressIndicator(),
            Text('Loading contributions…'),
          ],
        ),
        HistoryPhase.firstError => Column(
          children: [
            Text(controller.failure!.message),
            TextButton(
              onPressed: controller.retry,
              child: const Text('Try again'),
            ),
          ],
        ),
        HistoryPhase.filteredEmpty => Column(
          children: [
            const Text('No contributions match these filters.'),
            TextButton(
              onPressed: widget.onClearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ),
        _ => const Text('No contributions yet.'),
      };
    }

    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.phase == HistoryPhase.laterError) {
      return Column(
        children: [
          Text(controller.failure!.message),
          TextButton(
            onPressed: controller.retry,
            child: const Text('Try the next page again'),
          ),
        ],
      );
    }

    if (controller.phase == HistoryPhase.end) {
      return const Text('End of contributions');
    }

    return TextButton(
      onPressed: controller.loadMore,
      child: const Text('Load more'),
    );
  }
}

class ContributionHistoryTile extends StatelessWidget {
  const new({required this.item, super.key});

  final Contribution item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.memberName),
            Text(item.amount.formatRand()),
            Text('Cycle ${item.cycleNumber}'),
            ContributionStatusBadge(status: item.status),
            if (item.paidAtUtc != null)
              Text(formatJohannesburgDate(item.paidAtUtc!, includeTime: true)),
          ],
        ),
      ),
    );
  }
}
