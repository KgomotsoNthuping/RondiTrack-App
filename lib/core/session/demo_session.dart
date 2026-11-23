import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';

part 'demo_session.g.dart';

abstract interface class SessionMember {
  String get name;

  String get displayName;

  String get email;
}

enum DemoPersona implements SessionMember {
  lerato('Lerato', 'lerato@ronditrack.co.za'),
  nandi('Nandi', 'nandi@ronditrack.co.za'),
  naledi('Naledi', 'naledi@ronditrack.co.za');

  const new(this.displayName, this.email);

  @override
  String get name => switch (this) {
    DemoPersona.lerato => 'lerato',
    DemoPersona.nandi => 'nandi',
    DemoPersona.naledi => 'naledi',
  };

  @override
  final String displayName;

  @override
  final String email;
}

final class _AccountMember implements SessionMember {
  const new({required this.name, required this.email});

  @override
  final String name;

  @override
  final String email;

  @override
  String get displayName => email.split('@').first;
}

@Riverpod(keepAlive: true)
class DemoSession extends _$DemoSession {
  @override
  SessionMember? build() {
    if (!ref.watch(useApiRepositoriesProvider)) {
      return null;
    }

    final account = ref.watch(
      sessionStateProvider.select(
        (value) => switch (value) {
          AuthSignedIn(:final identity, :final sessionId) => (
            id: identity.userId,
            email: identity.email,
            sessionId: sessionId,
          ),
          AuthRestoring() || AuthSignedOut() => null,
        },
      ),
    );

    return account == null
        ? null
        : _AccountMember(name: account.id, email: account.email);
  }

  bool signIn(String email) {
    if (ref.read(useApiRepositoriesProvider)) {
      return false;
    }

    final normalized = email.trim().toLowerCase();

    for (final persona in DemoPersona.values) {
      if (persona.email == normalized) {
        state = persona;
        return true;
      }
    }

    return false;
  }

  void select(DemoPersona persona) {
    if (state != null) {
      signIn(persona.email);
    }
  }

  void signOut() {
    if (ref.read(useApiRepositoriesProvider)) {
      unawaited(ref.read(sessionCoordinatorProvider).signOut());
    } else {
      state = null;
    }
  }
}
