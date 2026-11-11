import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'demo_session.g.dart';

enum DemoPersona {
  lerato('Lerato'),
  nandi('Nandi'),
  naledi('Naledi');

  const new(this.displayName);

  final String displayName;
}

@Riverpod(keepAlive: true)
class DemoSession extends _$DemoSession {
  @override
  DemoPersona build() => DemoPersona.lerato;

  void select(DemoPersona persona) {
    state = persona;
  }
}
