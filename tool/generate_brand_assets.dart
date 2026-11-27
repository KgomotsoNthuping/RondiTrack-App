import 'dart:io';

import 'package:image/image.dart' as img;

const _brands = [
  (
    name: 'dev',
    label: 'DEV',
    background: 0x9AE600,
    ink: 0x192E03,
  ),
  (
    name: 'staging',
    label: 'STG',
    background: 0x0F172B,
    ink: 0x9AE600,
  ),
  (
    name: 'prod',
    label: 'PROD',
    background: 0xF7FEE7,
    ink: 0x192E03,
  ),
];

Future<void> main() async {
  final pubspec = File('pubspec.yaml');

  if (!pubspec.existsSync() ||
      !RegExp(
        r'^name: ronditrack$',
        multiLine: true,
      ).hasMatch(await pubspec.readAsString())) {
    stderr.writeln(
      'Run this command from the RondiTrack-App repository root.',
    );
    exitCode = 1;
    return;
  }

  for (final brand in _brands) {
    final directory = Directory(
      'assets/branding/${brand.name}',
    );

    await directory.create(recursive: true);

    final foreground = _mark(
      brand.label,
      brand.ink,
    );

    final icon = img.Image(
      width: 1024,
      height: 1024,
      numChannels: 3,
    );

    img.fill(
      icon,
      color: _color(brand.background),
    );

    img.compositeImage(icon, foreground);

    await _save(
      '${directory.path}/icon.png',
      icon,
    );

    await _save(
      '${directory.path}/foreground.png',
      foreground,
    );

    await _save(
      '${directory.path}/monochrome.png',
      _mark(brand.label, 0xFFFFFF),
    );

    await _save(
      '${directory.path}/splash.png',
      img.copyResize(
        foreground,
        width: 1152,
        height: 1152,
        interpolation: img.Interpolation.cubic,
      ),
    );

    final hex = brand.background
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();

    final background = '#$hex';
    final path = directory.path;

    await File(
      'flutter_launcher_icons-${brand.name}.yaml',
    ).writeAsString(
      '''
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "$path/icon.png"
  min_sdk_android: 26
  adaptive_icon_background: "$background"
  adaptive_icon_foreground: "$path/foreground.png"
  adaptive_icon_foreground_inset: 0
  adaptive_icon_monochrome: "$path/monochrome.png"
''',
    );

    await File(
      'flutter_native_splash-${brand.name}.yaml',
    ).writeAsString(
      '''
flutter_native_splash:
  android: true
  ios: false
  web: false
  android_min_sdk: 26
  color: "$background"
  color_dark: "$background"
  image: "$path/splash.png"
  image_dark: "$path/splash.png"
  android_gravity: center
  fullscreen: false
  android_12:
    color: "$background"
    color_dark: "$background"
    image: "$path/splash.png"
    image_dark: "$path/splash.png"
''',
    );

    stdout.writeln(
      'Created ${brand.name} branding sources '
      'and generator configs.',
    );
  }
}

img.Image _mark(String label, int ink) {
  final image = img.Image(
    width: 1024,
    height: 1024,
    numChannels: 4,
  );

  final color = _color(ink);

  void line(
    int x1,
    int y1,
    int x2,
    int y2,
  ) {
    img.drawLine(
      image,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: color,
      thickness: 52,
      antialias: true,
    );
  }

  line(390, 300, 390, 600);
  line(390, 300, 550, 300);
  line(550, 300, 610, 355);
  line(610, 355, 610, 415);
  line(610, 415, 550, 470);
  line(550, 470, 390, 470);
  line(510, 470, 630, 600);

  final text = img.Image(
    width: 180,
    height: 64,
    numChannels: 4,
  );

  img.drawString(
    text,
    label,
    font: img.arial48,
    color: color,
  );

  final badge = img.copyResize(
    text,
    width: 300,
    height: 106,
    interpolation: img.Interpolation.cubic,
  );

  img.compositeImage(
    image,
    badge,
    dstX: 362,
    dstY: 640,
  );

  return image;
}

img.ColorRgb8 _color(int hex) => img.ColorRgb8(
  (hex >> 16) & 255,
  (hex >> 8) & 255,
  hex & 255,
);

Future<void> _save(
  String path,
  img.Image image,
) => File(path)
    .writeAsBytes(img.encodePng(image))
    .then<void>((_) {});