import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/version/installed_version.dart';
import 'package:ronditrack/core/version/package_version_source.dart';

final versionSourceProvider = Provider<VersionSource>(
  (ref) => const PackageVersionSource(),
);

final installedVersionProvider = FutureProvider<InstalledVersion?>((ref) async {
  final source = ref.watch(versionSourceProvider);

  try {
    final version = await source.read().timeout(const Duration(seconds: 3));

    if (version.version.trim().isEmpty || version.buildNumber.trim().isEmpty) {
      return null;
    }

    return version;
  } on Object {
    return null;
  }
});
