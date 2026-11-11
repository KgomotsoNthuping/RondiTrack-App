import 'package:flutter/material.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';
import 'package:ronditrack/features/home/presentation/home_screen.dart';

class RondiTrackApp extends StatelessWidget {
  const new({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.flavor.displayName,
      debugShowCheckedModeBanner: false,
      theme: RondiTrackTheme.light,
      darkTheme: RondiTrackTheme.dark,
      home: const HomeScreen(),
    );
  }
}
