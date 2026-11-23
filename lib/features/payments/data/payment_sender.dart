import 'package:dio/dio.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/features/payments/domain/pending_payment.dart';

final class PaymentSender {
  new(this._readDio, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Dio Function() _readDio;
  final DateTime Function() _clock;

  Future<PaymentReply> send(PendingPayment payment) async {
    try {
      final response = await _readDio().post<Object?>(
        '/api/v1/stokvels/'
        '${Uri.encodeComponent(payment.stokvelId)}/cycles/'
        '${Uri.encodeComponent(payment.cycleId)}/contributions',
        data: payment.frozenBody,
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Idempotency-Key': payment.key},
        ),
      );

      final data = response.data;

      if (response.statusCode != 201 || data is! Map<String, dynamic>) {
        return const PaymentUnanswered(ServerFailure());
      }

      final id = data['id'];
      final userId = data['userId'];
      final stokvelId = data['stokvelId'];
      final cycleId = data['contributionCycleId'];
      final status = data['status'];

      final matches =
          id is String &&
          id.isNotEmpty &&
          userId is String &&
          userId.toLowerCase() == payment.userId.toLowerCase() &&
          stokvelId is String &&
          stokvelId.toLowerCase() == payment.stokvelId.toLowerCase() &&
          cycleId is String &&
          cycleId.toLowerCase() == payment.cycleId.toLowerCase() &&
          data['amountInCents'] == payment.amount.value &&
          (status == 'Paid' || status == 'Confirmed');

      if (!matches) {
        return const PaymentUnanswered(ServerFailure());
      }

      return PaymentAccepted(id);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final failure = mapFailure(error, isRead: false);

      if (status == 429) {
        return PaymentWaiting(
          _retryAt(
            error.response?.headers.value('retry-after'),
            _clock().toUtc(),
          ),
        );
      }

      if (const [400, 403, 404, 409, 422].contains(status)) {
        return PaymentRefused(failure);
      }

      return PaymentUnanswered(failure);
    } on Object {
      return const PaymentUnanswered(ServerFailure());
    }
  }
}

DateTime _retryAt(String? header, DateTime nowUtc) {
  final value = header?.trim() ?? '';
  final seconds = int.tryParse(value);

  if (seconds != null && seconds >= 0) {
    return nowUtc.add(Duration(seconds: seconds));
  }

  final match = RegExp(
    r'^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) '
    r'(\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(value);

  if (match != null) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months.indexOf(match[2]!);

    if (month >= 0) {
      final deadline = DateTime.utc(
        int.parse(match[3]!),
        month + 1,
        int.parse(match[1]!),
        int.parse(match[4]!),
        int.parse(match[5]!),
        int.parse(match[6]!),
      );

      return deadline.isBefore(nowUtc) ? nowUtc : deadline;
    }
  }

  return nowUtc.add(const Duration(minutes: 1));
}
