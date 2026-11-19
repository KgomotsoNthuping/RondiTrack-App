import 'package:dio/dio.dart';
import 'package:dio/io.dart';

bool get platformUsesBrowserCookies => false;

HttpClientAdapter createPlatformAdapter({bool withCredentials = false}) {
  return IOHttpClientAdapter();
}
