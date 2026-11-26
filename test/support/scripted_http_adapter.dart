import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef RecordedRequest = ({
  String method,
  String path,
  Map<String, dynamic> headers,
  Object? body,
});

final class ScriptedHttpAdapter implements HttpClientAdapter {
  new(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      method: options.method,
      path: options.path,
      headers: Map<String, dynamic>.from(options.headers),
      body: options.data,
    ));

    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  int status,
  Object? data, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);
