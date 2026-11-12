import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ronditrack/app/ronditrack_app.dart';
import 'package:ronditrack/core/config/app_config.dart';

void main() {
  usePathUrlStrategy();
  final config = AppConfig.fromEnvironment();
  runApp(ProviderScope(child: RondiTrackApp(config: config)));
}
