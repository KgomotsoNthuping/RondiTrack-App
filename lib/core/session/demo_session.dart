import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'demo_session.g.dart';

enum DemoPersona {
  lerato('Lerato', 'lerato@ronditrack.co.za'),
  nandi('Nandi', 'nandi@ronditrack.co.za'),
  naledi('Naledi', 'naledi@ronditrack.co.za');

  const new(this.displayName, this.email);

  final String displayName;
  final String email;
}

@Riverpod(keepAlive: true)
class DemoSession extends _$DemoSession {
  @override
  DemoPersona? build() => null;

  bool signIn(String email) {
    final normalizedEmail = email.trim().toLowerCase();

    for (final persona in DemoPersona.values) {
      if (persona.email == normalizedEmail) {
        state = persona;
        return true;
      }
    }

    return false;
  }

  void select(DemoPersona persona) {
    if (state != null) {
      state = persona;
    }
  }

  void signOut() {
    state = null;
  }
}