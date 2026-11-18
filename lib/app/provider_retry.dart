import 'package:ronditrack/core/errors/failure.dart';

Duration? appProviderRetry(int retryCount, Object error) {
  return switch (error) {
    OfflineFailure(isRead: true) when retryCount < 2 => Duration(
      milliseconds: 300 * (1 << retryCount),
    ),
    _ => null,
  };
}
