import 'package:flutter/material.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';

class RondiTrackApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RondiTrack Mobile',
      debugShowCheckedModeBanner: false,
      theme: RondiTrackTheme.light,
      darkTheme: RondiTrackTheme.dark,
      home: Scaffold(appBar: AppBar(title: const Text('RondiTrack'))),
    );
  }
}