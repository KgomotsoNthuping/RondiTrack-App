final class InstalledVersion {
  const InstalledVersion({
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;
}

abstract interface class VersionSource {
  Future<InstalledVersion> read();
}