import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/money/cents.dart';

enum PaymentPhase { pending, waiting, expired, clockMismatch }

final class PendingPayment {
  const PendingPayment({
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
  const PaymentNotice({
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
  const PaymentReply();
}

final class PaymentAccepted extends PaymentReply {
  const PaymentAccepted(this.contributionId);

  final String contributionId;
}

final class PaymentRefused extends PaymentReply {
  const PaymentRefused(this.failure);

  final Failure failure;
}

final class PaymentWaiting extends PaymentReply {
  const PaymentWaiting(this.retryAtUtc);

  final DateTime retryAtUtc;
}

final class PaymentUnanswered extends PaymentReply {
  const PaymentUnanswered(this.failure);

  final Failure failure;
}
