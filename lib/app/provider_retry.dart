import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/features/payouts/domain/payout_repository.dart';

Duration? appProviderRetry(int retryCount, Object error) {
  if (error is PayoutOrderNotFound) {
    return null;
  }

  return ProviderContainer.defaultRetry(retryCount, error);
}
