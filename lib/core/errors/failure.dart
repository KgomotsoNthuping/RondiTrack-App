sealed class Failure implements Exception {
  const new({this.detail, this.correlationId});

  final String? detail;
  final String? correlationId;

  String get message;

  bool get canRetry => false;

  @override
  String toString() => message;
}

final class ValidationFailure extends Failure {
  new({
    required Map<String, List<String>> errors,
    super.detail,
    super.correlationId,
  }) : errors = Map.unmodifiable({
         for (final entry in errors.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       });

  final Map<String, List<String>> errors;

  @override
  String get message => detail ?? 'Check the highlighted fields.';
}

final class UnauthorizedFailure extends Failure {
  const new({super.correlationId});

  @override
  String get message => 'Please sign in again.';
}

final class ForbiddenFailure extends Failure {
  const new({super.detail, super.correlationId});

  @override
  String get message => detail ?? 'You do not have permission to do that.';
}

final class NotFoundFailure extends Failure {
  const new({super.correlationId});

  @override
  String get message => 'Not found';
}

final class ConflictFailure extends Failure {
  const new({super.detail, super.correlationId});

  @override
  String get message =>
      detail ?? 'This information changed elsewhere. Reload and try again.';
}

final class RuleFailure extends Failure {
  const new({super.detail, super.correlationId});

  @override
  String get message => detail ?? 'This action is not allowed right now.';
}

final class RateLimitedFailure extends Failure {
  const new({this.retryAfterSeconds, super.detail, super.correlationId});

  final int? retryAfterSeconds;

  @override
  String get message {
    final seconds = retryAfterSeconds;
    if (seconds == null) {
      return detail ?? 'Too many attempts. Try again later.';
    }

    return 'Too many attempts. Try again in $seconds seconds.';
  }
}

final class ServerFailure extends Failure {
  const new({super.correlationId});

  @override
  String get message => 'Sorry, something went wrong on our side.';
}

final class OfflineFailure extends Failure {
  const new({required this.isRead, super.correlationId});

  final bool isRead;

  @override
  String get message => 'You’re offline, or we couldn’t reach the server.';

  @override
  bool get canRetry => isRead;
}
