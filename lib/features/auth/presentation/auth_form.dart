import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/auth/application/auth_form_state.dart';

mixin AuthFormFeedback<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool submitting = false;
  Failure? failure;
  DateTime? _retryUntil;
  Timer? _timer;

  String get cooldownKey;

  @override
  void initState() {
    super.initState();

    _retryUntil = ref.read(authCooldownsProvider).read(cooldownKey);

    _startTimer();
  }

  int get waitSeconds {
    final until = _retryUntil;

    if (until == null) {
      return 0;
    }

    final milliseconds = until
        .difference(ref.read(authFormClockProvider)())
        .inMilliseconds;

    return milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  }

  bool get blocked => submitting || waitSeconds > 0;

  void clearFailure() {
    setState(() => failure = null);
  }

  void showFailure(Failure value) {
    _timer?.cancel();

    final seconds = value is RateLimitedFailure
        ? value.retryAfterSeconds
        : null;

    setState(() {
      failure = value;
      _retryUntil = seconds != null && seconds > 0
          ? ref.read(authFormClockProvider)().add(Duration(seconds: seconds))
          : null;
    });

    ref.read(authCooldownsProvider).write(cooldownKey, _retryUntil);

    _startTimer();
  }

  void _startTimer() {
    if (_retryUntil == null) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {});

      if (waitSeconds == 0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

String? authFieldError(Failure? failure, String field) {
  if (failure is! ValidationFailure) {
    return null;
  }

  for (final entry in failure.errors.entries) {
    final name = entry.key.split('.').last.toLowerCase();

    if (name == field.toLowerCase() && entry.value.isNotEmpty) {
      return entry.value.join('\n');
    }
  }

  return null;
}

class AuthFailureNotice extends StatelessWidget {
  const new({required this.failure, this.signIn = false, super.key});

  final Failure failure;
  final bool signIn;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure) {
      UnauthorizedFailure() when signIn =>
        'The email and password do not match.',
      ValidationFailure() => 'Check the highlighted fields.',
      RateLimitedFailure() =>
        'Too many attempts. Please wait before trying again.',
      ConflictFailure() when !signIn => 'Please use a different email address.',
      _ => failure.message,
    };

    return FailureNotice(
      state: ScreenFailure<Object?>(
        message,
        canRetry: false,
        correlationId: failure.correlationId,
      ),
    );
  }
}

class AuthPage extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RondiTrack')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(subtitle),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
