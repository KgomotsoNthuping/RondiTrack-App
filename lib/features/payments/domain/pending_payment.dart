import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';

enum PaymentPhase { pending, waiting, expired, clockMismatch }

final class PendingPayment {
  const new({
    required this.key,
    required this.userId,
    required this.stokvelId,
    required this.cycleId,
    required this.amount,
    required this.frozenBody,
    required this.createdAtUtc,
    required this.phase,
    this.retryAtUtc,
  });

  final String key;
  final String userId;
  final String stokvelId;
  final String cycleId;
  final Cents amount;
  final String frozenBody;
  final DateTime createdAtUtc;
  final PaymentPhase phase;
  final DateTime? retryAtUtc;
}

enum PaymentNoticeKind { paid, refused, expired, clockMismatch }

final class PaymentNotice {
  const new({
    required this.key,
    required this.userId,
    required this.stokvelId,
    required this.cycleId,
    required this.amount,
    required this.kind,
    required this.createdAtUtc,
    this.detail,
    this.contributionId,
    this.errors = const {},
  });

  final String key;
  final String userId;
  final String stokvelId;
  final String cycleId;
  final Cents amount;
  final PaymentNoticeKind kind;
  final DateTime createdAtUtc;
  final String? detail;
  final String? contributionId;
  final Map<String, List<String>> errors;
}

sealed class PaymentReply {
  const new();
}

final class PaymentAccepted extends PaymentReply {
  const new(this.contributionId);

  final String contributionId;
}

final class PaymentRefused extends PaymentReply {
  const new(this.failure);

  final Failure failure;
}

final class PaymentWaiting extends PaymentReply {
  const new(this.retryAtUtc);

  final DateTime retryAtUtc;
}

final class PaymentUnanswered extends PaymentReply {
  const new(this.failure);

  final Failure failure;
}
