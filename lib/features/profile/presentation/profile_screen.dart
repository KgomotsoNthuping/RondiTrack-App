import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/session/demo_session.dart';

class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(demoSessionProvider);
    if (persona == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  persona.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(persona.email),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () {
                      ref.read(demoSessionProvider.notifier).signOut();
                    },
                    child: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}