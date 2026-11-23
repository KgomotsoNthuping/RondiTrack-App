import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/offline/cached_value.dart';

final class CacheController<T> extends ChangeNotifier {
  new({
    required Stream<CachedValue<T>?> cache,
    required Future<T> Function() load,
    required Future<bool> Function(T, int, DateTime) save,
    required Future<bool> Function(int) remove,
    required int Function() generation,
    required bool Function() isCurrent,
    DateTime Function()? clock,
  }) : _load = load,
       _save = save,
       _remove = remove,
       _generation = generation,
       _isCurrent = isCurrent,
       _clock = clock ?? DateTime.now {
    _subscription = cache.listen(
      _accept,
      onError: (Object error, StackTrace stack) {
        reportFailure(error is Failure ? error : const ServerFailure());
      },
    );
  }

  final Future<T> Function() _load;
  final Future<bool> Function(T, int, DateTime) _save;
  final Future<bool> Function(int) _remove;
  final int Function() _generation;
  final bool Function() _isCurrent;
  final DateTime Function() _clock;

  late final StreamSubscription<CachedValue<T>?> _subscription;

  CachedValue<T>? _cached;
  Failure? _failure;
  Future<void>? _flight;
  bool _refreshing = false;
  bool _closed = false;

  CachedValue<T>? get cached => _cached;
  Failure? get failure => _failure;
  bool get refreshing => _refreshing;

  void reportSuccess() {
    if (!_closed && _isCurrent()) {
      _failure = null;
      notifyListeners();
    }
  }

  void reportFailure(Failure failure) {
    if (!_closed && _isCurrent()) {
      _failure = failure;

      if (failure is NotFoundFailure) {
        _cached = null;
      }

      notifyListeners();
    }
  }

  void _accept(CachedValue<T>? value) {
    if (_closed || !_isCurrent()) {
      return;
    }

    final previous = _cached;
    _cached = value;

    if (value != null &&
        (previous == null ||
            value.updatedAtUtc.isAfter(previous.updatedAtUtc))) {
      _failure = null;
    }

    notifyListeners();
  }

  Future<void> refresh() {
    if (_closed || !_isCurrent()) {
      return Future<void>.value();
    }

    final pending = _flight;

    if (pending != null) {
      return pending;
    }

    late final Future<void> flight;

    flight = _refresh().whenComplete(() {
      if (identical(_flight, flight)) {
        _flight = null;
      }
    });

    _flight = flight;
    return flight;
  }

  Future<void> _refresh() async {
    final generation = _generation();
    _refreshing = true;
    notifyListeners();

    try {
      final value = await _load();

      if (_closed || !_isCurrent()) {
        return;
      }

      final accepted = await _save(value, generation, _clock().toUtc());

      if (accepted && !_closed && _isCurrent()) {
        _failure = null;
      }
    } on Object catch (error) {
      if (_closed || !_isCurrent()) {
        return;
      }

      final failure = error is Failure ? error : const ServerFailure();

      if (failure is NotFoundFailure) {
        final removed = await _remove(generation);

        if (removed && !_closed && _isCurrent()) {
          _cached = null;
          _failure = failure;
        }
      } else {
        _failure = failure;
      }
    } finally {
      _refreshing = false;

      if (!_closed && _isCurrent()) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _cached = null;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
