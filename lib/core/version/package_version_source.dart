import 'package:package_info_plus/package_info_plus.dart';
import 'package:ronditrack/core/version/installed_version.dart';

final class PackageVersionSource implements VersionSource {
  const new();

  @override
  Future<InstalledVersion> read() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledVersion(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  }
}
