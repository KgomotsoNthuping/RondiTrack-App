import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';

class RondiTrackApp extends ConsumerWidget {
  const new({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: config.flavor.displayName,
      debugShowCheckedModeBanner: false,
      theme: RondiTrackTheme.light,
      darkTheme: RondiTrackTheme.dark,
      routerConfig: ref.watch(appRouterProvider(config.flavor)),
    );
  }
}
