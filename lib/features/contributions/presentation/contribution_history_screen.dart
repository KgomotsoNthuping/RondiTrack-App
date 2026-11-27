import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:ronditrack/core/dates/calendar_date.dart';
import 'package:ronditrack/core/dates/south_african_dates.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/contributions/application/contribution_history_controller.dart';
import 'package:ronditrack/features/contributions/domain/contribution_history.dart';
import 'package:ronditrack/features/contributions/presentation/contribution_history_list.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_workflow_provider.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

@Dependencies([homeRepository])
class ContributionHistoryScreen extends ConsumerWidget {
  const new({
    required this.stokvelId,
    required this.filters,
    this.invalidFilters = false,
    super.key,
  });

  final String stokvelId;
  final HistoryFilter filters;
  final bool invalidFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStateProvider);

    if (session is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final workflow = ref.watch(
      stokvelWorkflowProvider((
        userId: session.identity.userId,
        sessionId: session.sessionId,
      )),
    );

    return _HistoryBody(
      key: ValueKey((stokvelId, session.identity.userId, session.sessionId)),
      stokvelId: stokvelId,
      workflow: workflow,
      filters: filters,
      invalidFilters: invalidFilters,
    );
  }
}

@Dependencies([homeRepository])
class _HistoryBody extends StatefulWidget {
  const new({
    required this.stokvelId,
    required this.workflow,
    required this.filters,
    required this.invalidFilters,
    super.key,
  });

  final String stokvelId;
  final StokvelWorkflow workflow;
  final HistoryFilter filters;
  final bool invalidFilters;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  late final ContributionHistoryController _pager;
  late Future<HistoryOptions> _options;
  late HistoryFilter _selection;

  @override
  void initState() {
    super.initState();

    _selection = widget.filters;

    _pager = ContributionHistoryController(
      filters: widget.filters,
      load: (filters, token) =>
          widget.workflow.history(widget.stokvelId, filters, token),
    );

    _options = widget.workflow.options(widget.stokvelId);

    if (!widget.invalidFilters) {
      unawaited(_pager.refresh());
    }
  }

  @override
  void didUpdateWidget(covariant _HistoryBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.invalidFilters &&
        (widget.filters != oldWidget.filters || oldWidget.invalidFilters)) {
      _selection = widget.filters;
      unawaited(_pager.changeFilters(widget.filters));
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _apply(HistoryFilter filters) {
    setState(() => _selection = filters);
    context.go(historyLocation(widget.stokvelId, filters));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contributions'),
        leading: BackButton(
          onPressed: () => context.go(
            Uri(pathSegments: ['', 'stokvels', widget.stokvelId]).toString(),
          ),
        ),
      ),
      body: ContributionHistoryList(
        controller: _pager,
        invalidFilters: widget.invalidFilters,
        onClearFilters: () => _apply(allContributions),
        header: FutureBuilder<HistoryOptions>(
          future: _options,
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _filters(snapshot.data ?? emptyHistoryOptions),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () => setState(() {
                        _options = widget.workflow.options(widget.stokvelId);
                      }),
                      child: const Text('Retry member and cycle choices'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filters(HistoryOptions options) {
    final selected = _selection;
    final cycleIds = options.cycles.map((item) => item.id).toSet();
    final memberIds = options.members.map((item) => item.id).toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final preferred = 220 * scale;
        final width = constraints.maxWidth < preferred
            ? constraints.maxWidth
            : preferred;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: ValueKey(('cycle', selected.cycleId)),
                initialValue: selected.cycleId ?? '',
                isExpanded: true,
                isDense: scale <= 1,
                decoration: const InputDecoration(labelText: 'Cycle'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All cycles')),
                  for (final item in options.cycles)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text('Cycle ${item.number}'),
                    ),
                  if (selected.cycleId != null &&
                      !cycleIds.contains(selected.cycleId))
                    DropdownMenuItem(
                      value: selected.cycleId,
                      child: const Text('Selected cycle'),
                    ),
                ],
                onChanged: (value) => _apply((
                  cycleId: value == '' ? null : value,
                  status: selected.status,
                  memberId: selected.memberId,
                  days: selected.days,
                )),
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: ValueKey(('status', selected.status)),
                initialValue: selected.status?.name ?? '',
                isExpanded: true,
                isDense: scale <= 1,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All statuses'),
                  ),
                  for (final status in ContributionStatus.values)
                    DropdownMenuItem(
                      value: status.name,
                      child: Text(status.label),
                    ),
                ],
                onChanged: (value) => _apply((
                  cycleId: selected.cycleId,
                  status: value == null || value.isEmpty
                      ? null
                      : ContributionStatus.values.byName(value),
                  memberId: selected.memberId,
                  days: selected.days,
                )),
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: ValueKey(('member', selected.memberId)),
                initialValue: selected.memberId ?? '',
                isExpanded: true,
                isDense: scale <= 1,
                decoration: const InputDecoration(labelText: 'Member'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All members')),
                  for (final item in options.members)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                  if (selected.memberId != null &&
                      !memberIds.contains(selected.memberId))
                    DropdownMenuItem(
                      value: selected.memberId,
                      child: const Text('Selected member'),
                    ),
                ],
                onChanged: (value) => _apply((
                  cycleId: selected.cycleId,
                  status: selected.status,
                  memberId: value == '' ? null : value,
                  days: selected.days,
                )),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                selected.days == null
                    ? 'South African dates'
                    : '${formatCalendarDate(selected.days!.first)} – '
                          '${formatCalendarDate(selected.days!.last)}',
              ),
              onPressed: () async {
                final today = southAfricanCalendarDay(DateTime.now());
                final days = selected.days;

                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.utc(
                    days != null && days.first.year < 2000
                        ? days.first.year
                        : 2000,
                  ),
                  lastDate: DateTime.utc(
                    days != null && days.last.year > 2100
                        ? days.last.year
                        : 2100,
                    12,
                    31,
                  ),
                  currentDate: DateTime.utc(today.year, today.month, today.day),
                  initialDateRange: days == null
                      ? null
                      : DateTimeRange(
                          start: DateTime.utc(
                            days.first.year,
                            days.first.month,
                            days.first.day,
                          ),
                          end: DateTime.utc(
                            days.last.year,
                            days.last.month,
                            days.last.day,
                          ),
                        ),
                );

                if (picked != null && mounted) {
                  _apply((
                    cycleId: _selection.cycleId,
                    status: _selection.status,
                    memberId: _selection.memberId,
                    days: (
                      first: (
                        year: picked.start.year,
                        month: picked.start.month,
                        day: picked.start.day,
                      ),
                      last: (
                        year: picked.end.year,
                        month: picked.end.month,
                        day: picked.end.day,
                      ),
                    ),
                  ));
                }
              },
            ),
            TextButton(
              onPressed: () => _apply(allContributions),
              child: const Text('Clear filters'),
            ),
          ],
        );
      },
    );
  }
}

String historyLocation(String id, HistoryFilter filter) {
  return Uri(
    pathSegments: ['', 'stokvels', id],
    queryParameters: {
      'view': 'history',
      if (filter.cycleId != null) 'cycle': filter.cycleId,
      if (filter.status != null) 'status': filter.status!.name,
      if (filter.memberId != null) 'member': filter.memberId,
      if (filter.days != null) 'from': _isoDay(filter.days!.first),
      if (filter.days != null) 'to': _isoDay(filter.days!.last),
    },
  ).toString();
}

HistoryFilter? historyFilterFromUri(Uri uri) {
  try {
    final query = uri.queryParameters;
    final from = query['from'];
    final to = query['to'];
    SelectedDays? days;

    if (from != null || to != null) {
      if (from == null || to == null) {
        return null;
      }

      days = (first: _parseDay(from), last: _parseDay(to));

      southAfricanDateRange(firstDay: days.first, lastDay: days.last);
    }

    final status = query['status'];
    final cycle = query['cycle'];
    final member = query['member'];

    return (
      cycleId: cycle == null || cycle.isEmpty ? null : cycle,
      status: status == null || status.isEmpty
          ? null
          : ContributionStatus.values.byName(status),
      memberId: member == null || member.isEmpty ? null : member,
      days: days,
    );
  } on Object {
    return null;
  }
}

String _isoDay(CalendarDate day) {
  final year = day.year.toString().padLeft(4, '0');
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');

  return '$year-$month-$date';
}

CalendarDate _parseDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid calendar day.');
  }

  final parts = value.split('-').map(int.parse).toList();

  if (parts[0] < 1 || parts[0] > 9999) {
    throw const FormatException('Invalid calendar year.');
  }

  final date = DateTime.utc(parts[0], parts[1], parts[2]);

  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw const FormatException('Invalid calendar day.');
  }

  return (year: parts[0], month: parts[1], day: parts[2]);
}
