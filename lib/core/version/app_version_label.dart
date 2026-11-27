import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/version/version_providers.dart';

class AppVersionLabel extends ConsumerWidget {
  const new({required this.flavor, super.key});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unavailable = 'Version unavailable · ${flavor.name}';
    final label = ref
        .watch(installedVersionProvider)
        .when(
          data: (version) => version == null
              ? unavailable
              : 'Version ${version.version} (${version.buildNumber}) '
                    '· ${flavor.name}',
          loading: () => 'Reading version…',
          error: (_, _) => unavailable,
        );

    return SelectableText(
      label,
      key: const ValueKey('installed-version'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
