import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/config/app_config_provider.dart';
import 'package:ronditrack/core/offline/data/app_database.dart';

final offlineDatabaseProvider = Provider<AppDatabase>((ref) {
  final config = ref.watch(appConfigProvider);

  final address = base64Url
      .encode(utf8.encode(config.apiBaseUrl.toString()))
      .replaceAll('=', '')
      .replaceAll('_', '_u')
      .replaceAll('-', '_h');

  final database = AppDatabase.persistent(
    name: 'ronditrack_${config.flavor.name}_$address',
  );

  ref.onDispose(() {
    unawaited(database.close());
  });

  return database;
}, dependencies: [appConfigProvider]);
