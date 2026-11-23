abstract interface class SignOutMarker {
  Future<bool> read();

  Future<void> write(bool signedOut);
}

final class MemorySignOutMarker implements SignOutMarker {
  new({bool signedOut = false}) : _signedOut = signedOut;

  bool _signedOut;

  @override
  Future<bool> read() async => _signedOut;

  @override
  Future<void> write(bool signedOut) async {
    _signedOut = signedOut;
  }
}
