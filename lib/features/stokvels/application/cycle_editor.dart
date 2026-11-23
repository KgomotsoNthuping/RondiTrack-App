import 'package:flutter/foundation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_forms.dart';

final class CycleEditor extends ChangeNotifier {
  new({
    required EditableCycle initial,
    required Future<EditableCycle> Function() loadLatest,
    required Future<EditableCycle> Function(int, Cents, int) save,
  }) : latest = initial,
       displayed = initial,
       _loadLatest = loadLatest,
       _save = save;

  final Future<EditableCycle> Function() _loadLatest;
  final Future<EditableCycle> Function(int, Cents, int) _save;

  EditableCycle latest;
  EditableCycle displayed;
  Failure? failure;
  Failure? reloadFailure;

  bool saving = false;
  bool requiresReview = false;
  bool canAcceptLatest = false;
  bool _closed = false;

  Future<bool> submit(int number, Cents target) async {
    if (_closed || saving || requiresReview) {
      return false;
    }

    final before = latest;
    displayed = before.preview(number, target);
    failure = null;
    reloadFailure = null;
    saving = true;
    notifyListeners();

    try {
      final saved = await _save(number, target, before.version);

      if (_closed) {
        return false;
      }

      latest = saved;
      displayed = saved;
      return true;
    } on Object catch (error) {
      if (_closed) {
        return false;
      }

      displayed = before;
      failure = error is Failure ? error : const ServerFailure();

      if (failure is ConflictFailure) {
        requiresReview = true;
        canAcceptLatest = false;
        await reloadLatest();
      }

      return false;
    } finally {
      if (!_closed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> reloadLatest() async {
    try {
      final fresh = await _loadLatest();

      if (!_closed) {
        latest = fresh;
        displayed = fresh;
        reloadFailure = null;
        canAcceptLatest = true;
      }
    } on Object catch (error) {
      if (!_closed) {
        reloadFailure = error is Failure ? error : const ServerFailure();
        canAcceptLatest = false;
      }
    }

    if (!_closed) {
      notifyListeners();
    }
  }

  void acceptLatest() {
    if (canAcceptLatest && !_closed) {
      requiresReview = false;
      failure = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
