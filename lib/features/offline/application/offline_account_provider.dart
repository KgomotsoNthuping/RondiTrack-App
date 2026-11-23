import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/offline/cache_controller.dart';
import 'package:ronditrack/core/offline/data/offline_database_provider.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/home/data/home_cache.dart';
import 'package:ronditrack/features/home/domain/home_entry.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_detail_provider.dart';
import 'package:ronditrack/features/stokvels/application/stokvel_workflow_provider.dart';
import 'package:ronditrack/features/stokvels/data/stokvel_cache.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';

typedef OfflineAccountKey = ({String userId, int sessionId});

typedef CachedStokvelKey = ({OfflineAccountKey account, String stokvelId});

final cachedHomeProvider = Provider.autoDispose
    .family<CacheController<List<HomeEntry>>, OfflineAccountKey>(
      (ref, account) {
        final database = ref.watch(offlineDatabaseProvider);
        final coordinator = ref.watch(sessionCoordinatorProvider);
        final cache = HomeCache(database);

        bool isCurrent() {
          final state = coordinator.state;

          return state is AuthSignedIn &&
              state.identity.userId == account.userId &&
              state.sessionId == account.sessionId &&
              coordinator.epoch == account.sessionId;
        }

        final controller = CacheController<List<HomeEntry>>(
          cache: cache.watch(account.userId),
          load: () =>
              ref.read(homeRepositoryProvider).fetchHome(account.userId),
          save: (value, generation, updatedAt) => cache.replace(
            generation: generation,
            userId: account.userId,
            entries: value,
            updatedAtUtc: updatedAt,
          ),
          remove: (generation) =>
              cache.remove(generation: generation, userId: account.userId),
          generation: () => database.generation,
          isCurrent: isCurrent,
        );

        ref.listen(homeRepositoryProvider, (_, next) {
          unawaited(controller.refresh());
        });

        ref.onDispose(controller.dispose);
        return controller;
      },
      dependencies: [
        offlineDatabaseProvider,
        sessionCoordinatorProvider,
        homeRepositoryProvider,
      ],
    );

final cachedStokvelProvider = Provider.autoDispose
    .family<CacheController<Stokvel>, CachedStokvelKey>(
      (ref, key) {
        final database = ref.watch(offlineDatabaseProvider);
        final coordinator = ref.watch(sessionCoordinatorProvider);
        final cache = StokvelCache(database);

        bool isCurrent() {
          final state = coordinator.state;

          return state is AuthSignedIn &&
              state.identity.userId == key.account.userId &&
              state.sessionId == key.account.sessionId &&
              coordinator.epoch == key.account.sessionId;
        }

        final controller = CacheController<Stokvel>(
          cache: cache.watch(key.account.userId, key.stokvelId),
          load: () => ref
              .read(stokvelWorkflowApiProvider)
              .detail(key.account.userId, key.stokvelId),
          save: (value, generation, updatedAt) => cache.replace(
            generation: generation,
            userId: key.account.userId,
            value: value,
            updatedAtUtc: updatedAt,
          ),
          remove: (generation) => cache.remove(
            generation: generation,
            userId: key.account.userId,
            stokvelId: key.stokvelId,
          ),
          generation: () => database.generation,
          isCurrent: isCurrent,
        );

        ref.listen(stokvelRepositoryProvider, (_, next) {
          unawaited(controller.refresh());
        });

        ref.onDispose(controller.dispose);
        return controller;
      },
      dependencies: [
        offlineDatabaseProvider,
        sessionCoordinatorProvider,
        stokvelRepositoryProvider,
        stokvelWorkflowApiProvider,
      ],
    );
