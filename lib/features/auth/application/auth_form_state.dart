import 'package:flutter_riverpod/flutter_riverpod.dart';

final authFormClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final authCooldownsProvider = Provider<AuthCooldowns>((ref) => AuthCooldowns());

final class AuthCooldowns {
  final _deadlines = <String, DateTime>{};

  DateTime? read(String form) => _deadlines[form];

  void write(String form, DateTime? until) {
    if (until == null) {
      _deadlines.remove(form);
    } else {
      _deadlines[form] = until;
    }
  }
}
