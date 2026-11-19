import 'dart:convert';

import 'package:ronditrack/core/session/auth_models.dart';

AuthIdentity decodeAuthClaims(String token) {
  try {
    final parts = token.split('.');

    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const FormatException();
    }

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );

    final decoded = jsonDecode(payload);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException();
    }

    final userId = decoded['sub'];
    final email = decoded['email'];
    final role = decoded['role'];
    final tokenId = decoded['jti'];

    if (userId is! String ||
        userId.trim().isEmpty ||
        email is! String ||
        email.trim().isEmpty ||
        (role != null && role is! String) ||
        (tokenId != null && tokenId is! String)) {
      throw const FormatException();
    }

    return AuthIdentity(
      userId: userId,
      email: email,
      platformRole: role as String?,
      tokenId: tokenId as String?,
    );
  } on Object {
    throw const FormatException('Invalid access token claims.');
  }
}
