import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/core/result/result.dart';

Future<Result<T>> apiResult<T>(
  Future<T> Function() operation, {
  required bool isRead,
}) async {
  try {
    return Ok(await operation());
  } on Object catch (error) {
    return Err(mapFailure(error, isRead: isRead));
  }
}
