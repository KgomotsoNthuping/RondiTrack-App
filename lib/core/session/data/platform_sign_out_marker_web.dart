import 'dart:js_interop';

import 'package:ronditrack/core/session/sign_out_marker.dart';

@JS('localStorage')
external _Storage get _storage;

extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);

  external void setItem(String key, String value);

  external void removeItem(String key);
}

SignOutMarker createSignOutMarker(String key) {
  return _BrowserSignOutMarker(key);
}

final class _BrowserSignOutMarker implements SignOutMarker {
  const _BrowserSignOutMarker(this.key);

  final String key;

  @override
  Future<bool> read() async => _storage.getItem(key) == '1';

  @override
  Future<void> write(bool signedOut) async {
    if (signedOut) {
      _storage.setItem(key, '1');
    } else {
      _storage.removeItem(key);
    }
  }
}
