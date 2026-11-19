import 'package:ronditrack/core/config/auth_config.dart';
import 'package:ronditrack/core/session/auth_models.dart';
import 'package:ronditrack/core/session/data/auth_paths.dart';

final _cookieValuePattern = RegExp(
  r'^[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]+$',
);

RefreshToken readRefreshCookie(
  List<String> setCookieHeaders,
  AuthConfig config,
) {
  RefreshToken? result;

  for (final header in setCookieHeaders) {
    final parts = header.split(';');
    final first = parts.first.trim();
    final separator = first.indexOf('=');

    if (separator <= 0) {
      continue;
    }

    final name = first.substring(0, separator);

    if (name != config.refreshCookieName) {
      continue;
    }

    if (result != null || header.contains('\r') || header.contains('\n')) {
      throw const FormatException('Invalid refresh cookie response.');
    }

    final value = first.substring(separator + 1);
    _validateValue(value);

    String? cookiePath;

    for (final part in parts.skip(1)) {
      final attribute = part.trim();
      final equals = attribute.indexOf('=');

      if (equals <= 0) {
        continue;
      }

      final attributeName = attribute.substring(0, equals).trim().toLowerCase();

      if (attributeName == 'path') {
        if (cookiePath != null) {
          throw const FormatException('Invalid refresh cookie path.');
        }

        cookiePath = attribute.substring(equals + 1).trim();
      }
    }

    if (cookiePath != config.refreshCookiePath) {
      throw const FormatException('Unexpected refresh cookie path.');
    }

    result = RefreshToken(value);
  }

  if (result == null) {
    throw const FormatException('The refresh cookie is missing.');
  }

  return result;
}

String refreshCookieHeader(
  RefreshToken token,
  AuthConfig config, {
  required String path,
}) {
  if (path != AuthPaths.refresh && path != AuthPaths.logout) {
    throw const FormatException('Refresh cookies require an auth endpoint.');
  }

  final scope = config.refreshCookiePath;
  final withinScope =
      scope == '/' ||
      path == scope ||
      path.startsWith(scope.endsWith('/') ? scope : '$scope/');

  if (!withinScope) {
    throw const FormatException('The endpoint is outside the cookie path.');
  }

  _validateValue(token.value);

  return '${config.refreshCookieName}=${token.value}';
}

void _validateValue(String value) {
  if (!_cookieValuePattern.hasMatch(value)) {
    throw const FormatException('Invalid refresh cookie value.');
  }
}
