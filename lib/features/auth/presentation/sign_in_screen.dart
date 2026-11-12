import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/session/demo_session.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  String? _error;

  void _submit() {
    final accepted = ref.read(demoSessionProvider.notifier).signIn(_email.text);
    if (!accepted) {
      setState(() {
        _error = 'Enter a recognised demo email.';
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RondiTrack')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign in',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Use a demo email to continue.'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() {
                          _error = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}