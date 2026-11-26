abstract interface class InstallationMessaging {
  bool get enabled;

  Stream<String> get onRegistered;

  Future<void> register();

  Future<void> unregister();
}

final class NoopInstallationMessaging implements InstallationMessaging {
  const new();

  @override
  bool get enabled => false;

  @override
  Stream<String> get onRegistered => const Stream.empty();

  @override
  Future<void> register() async {}

  @override
  Future<void> unregister() async {}
}
