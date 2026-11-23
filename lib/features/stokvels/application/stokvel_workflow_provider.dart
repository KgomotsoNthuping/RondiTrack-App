import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/offline/data/offline_database_provider.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/contributions/domain/contribution_history.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/offline/application/offline_account_provider.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_workflow_api.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_forms.dart';

final stokvelWorkflowApiProvider = Provider<StokvelWorkflowApi>(
  (ref) => StokvelWorkflowApi(() => ref.read(apiDioProvider)),
  dependencies: [apiDioProvider],
);

final stokvelWorkflowProvider = Provider.autoDispose
    .family<StokvelWorkflow, OfflineAccountKey>(
      (ref, account) {
        final workflow = StokvelWorkflow(ref, account);
        final keepAlive = ref.keepAlive();

        ref.listen(sessionStateProvider, (_, next) {
          if (next is! AuthSignedIn ||
              next.identity.userId != account.userId ||
              next.sessionId != account.sessionId) {
            keepAlive.close();
          }
        });

        ref.onDispose(workflow.dispose);
        return workflow;
      },
      dependencies: [
        offlineDatabaseProvider,
        sessionCoordinatorProvider,
        sessionStateProvider,
        stokvelWorkflowApiProvider,
        homeRepositoryProvider,
        cachedHomeProvider,
        cachedStokvelProvider,
      ],
    );

final class StokvelWorkflow {
  StokvelWorkflow(this._ref, this.account);

  final Ref _ref;
  final OfflineAccountKey account;
  bool _closed = false;

  bool get _current {
    if (_closed) {
      return false;
    }

    final session = _ref.read(sessionCoordinatorProvider);
    final state = session.state;

    return state is AuthSignedIn &&
        state.identity.userId == account.userId &&
        state.sessionId == account.sessionId &&
        session.epoch == account.sessionId;
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    if (!_current) {
      throw const UnauthorizedFailure();
    }

    final result = await operation();

    if (!_current) {
      throw const UnauthorizedFailure();
    }

    return result;
  }

  Future<String> create(CreateStokvelDraft draft) {
    return _guard(() async {
      final id = await _ref.read(stokvelWorkflowApiProvider).create(draft);

      if (_current) {
        await refreshHome();
      }

      return id;
    });
  }

  Future<EditableCycle> initialCycle(String id, String cycleId) {
    return _guard(() async {
      final db = _ref.read(offlineDatabaseProvider);
      final saved = await StokvelCache(db).read(account.userId, id);
      final current = saved?.value.currentCycle;

      if (current != null &&
          current.id.toLowerCase() == cycleId.toLowerCase() &&
          current.version != null &&
          current.version! > 0) {
        return EditableCycle.fromCache(current);
      }

      return _ref.read(stokvelWorkflowApiProvider).cycle(id, cycleId);
    });
  }

  Future<EditableCycle> latestCycle(String id, String cycleId) {
    return _guard(() async {
      final latest = await _ref
          .read(stokvelWorkflowApiProvider)
          .cycle(id, cycleId);

      if (_current) {
        await refreshStock(id);
      }

      return latest;
    });
  }

  Future<EditableCycle> saveCycle(
    String id,
    String cycleId,
    int number,
    Cents target,
    int version,
  ) {
    return _guard(() async {
      final saved = await _ref
          .read(stokvelWorkflowApiProvider)
          .updateCycle(
            id,
            cycleId,
            number: number,
            target: target,
            version: version,
          );

      if (_current) {
        await refreshScreens(id);
      }

      return saved;
    });
  }

  Future<HistoryPage> history(
    String id,
    HistoryFilter filters,
    String? token,
  ) {
    return _guard(
      () => _ref.read(stokvelWorkflowApiProvider).history(id, filters, token),
    );
  }

  Future<HistoryOptions> options(String id) {
    return _guard(() => _ref.read(stokvelWorkflowApiProvider).options(id));
  }

  Future<void> refreshScreens(String id) async {
    if (_current) {
      await Future.wait([refreshHome(), refreshStock(id)]);
    }
  }

  Future<void> refreshHome() async {
    if (!_current) {
      return;
    }

    final db = _ref.read(offlineDatabaseProvider);
    final generation = db.generation;

    try {
      final entries = await _ref
          .read(homeRepositoryProvider)
          .fetchHome(account.userId);

      if (!_current) {
        return;
      }

      final saved = await HomeCache(db).replace(
        generation: generation,
        userId: account.userId,
        entries: entries,
        updatedAtUtc: DateTime.now().toUtc(),
      );

      if (saved && _current) {
        _ref.read(cachedHomeProvider(account)).reportSuccess();
      }
    } on Object catch (error) {
      if (_current) {
        _ref.read(cachedHomeProvider(account)).reportFailure(
          error is Failure ? error : const ServerFailure(),
        );
      }
    }
  }

  Future<void> refreshStock(String id) async {
    if (!_current) {
      return;
    }

    final db = _ref.read(offlineDatabaseProvider);
    final generation = db.generation;
    final cache = StokvelCache(db);

    final provider = cachedStokvelProvider((
      account: account,
      stokvelId: id,
    ));

    try {
      final stock = await _ref
          .read(stokvelWorkflowApiProvider)
          .detail(account.userId, id);

      if (!_current) {
        return;
      }

      final saved = await cache.replace(
        generation: generation,
        userId: account.userId,
        value: stock,
        updatedAtUtc: DateTime.now().toUtc(),
      );

      if (saved && _current) {
        _ref.read(provider).reportSuccess();
      }
    } on Object catch (error) {
      if (!_current) {
        return;
      }

      final failure = error is Failure ? error : const ServerFailure();

      if (failure is NotFoundFailure) {
        final removed = await cache.remove(
          generation: generation,
          userId: account.userId,
          stokvelId: id,
        );

        if (!removed || !_current) {
          return;
        }
      }

      _ref.read(provider).reportFailure(failure);
    }
  }

  void dispose() {
    _closed = true;
  }
}