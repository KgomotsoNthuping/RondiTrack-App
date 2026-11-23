import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/config/app_config.dart';
import 'package:ronditrack/core/config/app_flavor_scope.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/demo_session.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/auth/presentation/auth_form.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const new({this.from, this.email, super.key});

  final String? from;
  final String? email;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with AuthFormFeedback<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  String get cooldownKey => 'sign-in';

  @override
  void initState() {
    super.initState();

    _email.text = widget.email ?? '';

    if (ref.read(useApiRepositoriesProvider)) {
      final session = ref.read(sessionStateProvider);

      if (session is AuthSignedOut) {
        failure = session.failure;
      }
    }
  }

  Future<void> _submit() async {
    if (blocked || !_form.currentState!.validate()) {
      return;
    }

    setState(() {
      submitting = true;
      failure = null;
    });

    Result<void> result;
    final email = _email.text.trim().toLowerCase();

    if (ref.read(useApiRepositoriesProvider)) {
      result = await ref
          .read(sessionCoordinatorProvider)
          .signIn(email: email, password: _password.text);
    } else {
      final accepted = ref.read(demoSessionProvider.notifier).signIn(email);

      result = accepted
          ? const Ok(null)
          : Err(
              ValidationFailure(
                errors: const {
                  'email': ['Enter a recognised demo email.'],
                },
              ),
            );
    }

    if (!mounted) {
      return;
    }

    setState(() => submitting = false);

    if (result case Err<void>(:final failure)) {
      showFailure(failure);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useApi = ref.watch(useApiRepositoriesProvider);
    final dev = AppFlavorScope.of(context) == AppFlavor.dev;
    final error = failure;

    return AuthPage(
      title: 'Sign in',
      subtitle: 'Welcome back to RondiTrack.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dev) ...[
                DropdownButtonFormField<DemoPersona>(
                  key: const ValueKey('dev-email-picker'),
                  decoration: const InputDecoration(
                    labelText: 'Development email',
                    errorMaxLines: 3,
                  ),
                  isExpanded: true,
                  items: [
                    for (final persona in DemoPersona.values)
                      DropdownMenuItem(
                        value: persona,
                        child: Text(persona.displayName),
                      ),
                  ],
                  onChanged: blocked
                      ? null
                      : (persona) {
                          if (persona == null) {
                            return;
                          }

                          _email.text = persona.email;
                          _password.clear();
                          clearFailure();
                        },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const ValueKey('sign-in-email'),
                controller: _email,
                enabled: !submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: useApi
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorMaxLines: 3,
                  errorText: authFieldError(error, 'email'),
                ),
                validator: (value) =>
                    value == null || !value.trim().contains('@')
                    ? 'Enter your email address.'
                    : null,
                onChanged: (_) => clearFailure(),
                onFieldSubmitted: useApi ? null : (_) => unawaited(_submit()),
              ),
              if (useApi) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('sign-in-password'),
                  controller: _password,
                  enabled: !submitting,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorMaxLines: 3,
                    errorText: authFieldError(error, 'password'),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () {
                        setState(() => _obscure = !_obscure);
                      },
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password.'
                      : null,
                  onChanged: (_) => clearFailure(),
                  onFieldSubmitted: (_) => unawaited(_submit()),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                AuthFailureNotice(failure: error, signIn: true),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('sign-in-submit'),
                onPressed: blocked ? null : () => unawaited(_submit()),
                child: Text(
                  submitting
                      ? 'Signing in…'
                      : waitSeconds > 0
                      ? 'Try again in ${waitSeconds}s'
                      : 'Sign in',
                ),
              ),
              if (useApi)
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          RegisterRoute(from: widget.from).go(context);
                        },
                  child: const Text('Create an account'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
