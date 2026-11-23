import 'package:flutter/foundation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/features/contributions/domain/contribution_history.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';

enum HistoryPhase {
  initialLoading,
  ready,
  empty,
  filteredEmpty,
  firstError,
  laterError,
  end,
}

final class ContributionHistoryController extends ChangeNotifier {
  ContributionHistoryController({
    required Future<HistoryPage> Function(HistoryFilter, String?) load,
    HistoryFilter filters = allContributions,
  }) : _load = load,
       _filters = filters;

  final Future<HistoryPage> Function(HistoryFilter, String?) _load;

  HistoryFilter _filters;
  List<Contribution> _items = [];
  Set<String> _visited = {};
  String? _next;
  Future<void>? _flight;
  Failure? _firstError;
  Failure? _laterError;
  Failure? _refreshError;

  int _revision = 0;
  bool _hasPage = false;
  bool _busy = false;
  bool _refreshing = false;
  bool _restart = false;
  bool _closed = false;

  HistoryFilter get filters => _filters;
  List<Contribution> get items => List.unmodifiable(_items);
  bool get loading => _busy;
  bool get refreshing => _refreshing;
  Failure? get failure => _firstError ?? _laterError ?? _refreshError;
  Failure? get refreshFailure => _refreshError;

  bool get canLoadMore =>
      !_busy &&
      _hasPage &&
      _next != null &&
      _refreshError == null &&
      _laterError == null;

  HistoryPhase get phase {
    if (_items.isEmpty) {
      if (_firstError != null) {
        return HistoryPhase.firstError;
      }

      if (!_hasPage) {
        return HistoryPhase.initialLoading;
      }

      return _filters.active
          ? HistoryPhase.filteredEmpty
          : HistoryPhase.empty;
    }

    if (_laterError != null) {
      return HistoryPhase.laterError;
    }

    return _next == null ? HistoryPhase.end : HistoryPhase.ready;
  }

  Future<void> changeFilters(HistoryFilter filters) {
    _filters = filters;
    _items = [];
    _visited = {};
    _next = null;
    _hasPage = false;
    _firstError = null;
    _laterError = null;
    _refreshError = null;

    return refresh();
  }

  Future<void> refresh() {
    if (_closed) {
      return Future<void>.value();
    }

    _revision++;
    _restart = true;
    notifyListeners();

    return _start(reset: true);
  }

  Future<void> loadMore() {
    if (_closed) {
      return Future<void>.value();
    }

    final pending = _flight;

    if (pending != null) {
      return pending;
    }

    if (!canLoadMore) {
      return Future<void>.value();
    }

    return _start(reset: false);
  }

  Future<void> retry() {
    if (_laterError != null) {
      _laterError = null;
      return loadMore();
    }

    return refresh();
  }

  Future<void> _start({required bool reset}) {
    final pending = _flight;

    if (pending != null) {
      return pending;
    }

    late final Future<void> flight;

    flight = _run(reset).whenComplete(() {
      if (identical(_flight, flight)) {
        _flight = null;
      }
    });

    _flight = flight;
    return flight;
  }

  Future<void> _run(bool reset) async {
    var replace = reset;

    do {
      _restart = false;
      await _batch(replace, _revision, _filters);
      replace = true;
    } while (_restart && !_closed);
  }

  Future<void> _batch(
    bool reset,
    int revision,
    HistoryFilter filters,
  ) async {
    _busy = true;
    _refreshing = reset && _hasPage;

    if (reset) {
      _firstError = null;
      _refreshError = null;
    }

    _laterError = null;
    notifyListeners();

    var token = reset ? null : _next;
    final visited = reset ? <String>{} : {..._visited};
    final ids = reset
        ? <String>{}
        : _items.map((item) => item.id).toSet();
    final found = <Contribution>[];

    try {
      while (!_closed && revision == _revision) {
        if (token != null && !visited.add(token)) {
          throw const FormatException('The API repeated a page token.');
        }

        final page = await _load(filters, token);

        if (_closed || revision != _revision) {
          return;
        }

        for (final item in page.items) {
          if (filters.matches(item) && ids.add(item.id)) {
            found.add(item);
          }
        }

        token = page.nextToken;

        if (token != null && token.isEmpty) {
          token = null;
        }

        if (found.isNotEmpty || token == null) {
          _items = reset ? found : [..._items, ...found];
          _next = token;
          _visited = visited;
          _hasPage = true;
          return;
        }
      }
    } on Object catch (error) {
      if (_closed || revision != _revision) {
        return;
      }

      final failure = error is Failure ? error : const ServerFailure();

      if (reset) {
        if (_items.isEmpty) {
          _firstError = failure;
        } else {
          _refreshError = failure;
        }
      } else {
        _laterError = failure;
      }
    } finally {
      if (!_closed && revision == _revision) {
        _busy = false;
        _refreshing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _revision++;
    _items = [];
    super.dispose();
  }
}