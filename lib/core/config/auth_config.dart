import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_config.g.dart';

final _cookieNamePattern = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

final _unsafePathCharacters = RegExp(r'[\x00-\x20\x7f\\;]');

final class AuthConfig {
  const new _({
    required this.refreshCookieName,
    required this.refreshCookiePath,
  });

  factory fromEnvironment() {
    return AuthConfig.parse(
      refreshCookieName: const String.fromEnvironment('REFRESH_COOKIE_NAME'),
      refreshCookiePath: const String.fromEnvironment('REFRESH_COOKIE_PATH'),
    );
  }

  factory parse({
    required String refreshCookieName,
    required String refreshCookiePath,
  }) {
    if (refreshCookieName.isEmpty ||
        refreshCookieName.trim() != refreshCookieName ||
        !_cookieNamePattern.hasMatch(refreshCookieName)) {
      throw const FormatException(
        'Set REFRESH_COOKIE_NAME to a valid cookie name.',
      );
    }

    final uri = Uri.tryParse(refreshCookiePath);

    if (refreshCookiePath.isEmpty ||
        !refreshCookiePath.startsWith('/') ||
        refreshCookiePath.startsWith('//') ||
        _unsafePathCharacters.hasMatch(refreshCookiePath) ||
        uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != refreshCookiePath ||
        uri.pathSegments.any(
          (segment) =>
              segment == '.' ||
              segment == '..' ||
              segment.contains('/') ||
              _unsafePathCharacters.hasMatch(segment),
        )) {
      throw const FormatException(
        'Set REFRESH_COOKIE_PATH to an absolute cookie path '
        'without a query or fragment.',
      );
    }

    return AuthConfig._(
      refreshCookieName: refreshCookieName,
      refreshCookiePath: refreshCookiePath,
    );
  }

  final String refreshCookieName;
  final String refreshCookiePath;
}

@Riverpod(keepAlive: true)
AuthConfig authConfig(Ref ref) => AuthConfig.fromEnvironment();
