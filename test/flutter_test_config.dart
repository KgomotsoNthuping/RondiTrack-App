import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:ronditrack/core/theme/ronditrack_theme.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: RondiTrackTheme.light,
      platformGoldensConfig: PlatformGoldensConfig(
        platforms: {HostPlatform.windows},
        renderShadows: false,
      ),
      ciGoldensConfig: const CiGoldensConfig(),
    ),
    run: testMain,
  );
}
