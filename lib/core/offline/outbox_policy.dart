enum OutboxAge { sendable, expired, clockMismatch }

final class OutboxPolicy {
  new({required this.maximumAge, required this.serverRetention}) {
    if (serverRetention <= Duration.zero) {
      throw ArgumentError.value(
        serverRetention,
        'serverRetention',
        'Must be greater than zero.',
      );
    }

    if (maximumAge <= Duration.zero || maximumAge >= serverRetention) {
      throw ArgumentError.value(
        maximumAge,
        'maximumAge',
        'Must be positive and shorter than server retention.',
      );
    }
  }

  final Duration maximumAge;
  final Duration serverRetention;

  OutboxAge assess({required DateTime createdAtUtc, required DateTime nowUtc}) {
    final age = nowUtc.toUtc().difference(createdAtUtc.toUtc());

    if (age.isNegative) {
      return OutboxAge.clockMismatch;
    }

    if (age >= maximumAge) {
      return OutboxAge.expired;
    }

    return OutboxAge.sendable;
  }
}
