import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

bool get platformUsesBrowserCookies => true;

HttpClientAdapter createPlatformAdapter({bool withCredentials = false}) {
  return BrowserHttpClientAdapter(
    withCredentials: withCredentials,
    enableCORSWarning: false,
  );
}
