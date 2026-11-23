import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/navigation/app_router.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/auth/presentation/auth_form.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const new({this.from, super.key});

  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with AuthFormFeedback<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  String get cooldownKey => 'register';

  Future<void> _submit() async {
    if (blocked || !_form.currentState!.validate()) {
      return;
    }

    setState(() {
      submitting = true;
      failure = null;
    });

    final result = await ref
        .read(sessionCoordinatorProvider)
        .register(
          fullName: _name.text.trim(),
          email: _email.text.trim().toLowerCase(),
          phoneNumber: _phone.text.trim(),
          password: _password.text,
        );

    if (!mounted) {
      return;
    }

    setState(() => submitting = false);

    switch (result) {
      case Ok<RegisteredAccount>(:final value):
        _password.clear();

        SignInRoute(from: widget.from, email: value.email).go(context);

      case Err<RegisteredAccount>(:final failure):
        showFailure(failure);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = failure;

    return AuthPage(
      title: 'Create account',
      subtitle: 'Start managing your stokvel memberships.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('register-name'),
                controller: _name,
                enabled: !submitting,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full name',
                  errorMaxLines: 3,
                  errorText: authFieldError(error, 'fullName'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your full name.'
                    : null,
                onChanged: (_) => clearFailure(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('register-email'),
                controller: _email,
                enabled: !submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorMaxLines: 3,
                  errorText: error is ConflictFailure
                      ? 'An account with this email already exists.'
                      : authFieldError(error, 'email'),
                ),
                validator: (value) =>
                    value == null || !value.trim().contains('@')
                    ? 'Enter your email address.'
                    : null,
                onChanged: (_) => clearFailure(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('register-phone'),
                controller: _phone,
                enabled: !submitting,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  errorMaxLines: 3,
                  errorText: authFieldError(error, 'phoneNumber'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your phone number.'
                    : null,
                onChanged: (_) => clearFailure(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('register-password'),
                controller: _password,
                enabled: !submitting,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
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
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter a password.' : null,
                onChanged: (_) => clearFailure(),
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                AuthFailureNotice(failure: error),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('register-submit'),
                onPressed: blocked ? null : () => unawaited(_submit()),
                child: Text(
                  submitting
                      ? 'Creating account…'
                      : waitSeconds > 0
                      ? 'Try again in ${waitSeconds}s'
                      : 'Register',
                ),
              ),
              TextButton(
                onPressed: submitting
                    ? null
                    : () {
                        SignInRoute(from: widget.from).go(context);
                      },
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
