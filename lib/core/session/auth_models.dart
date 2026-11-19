final class RefreshToken {
  const RefreshToken(this.value);

  final String value;

  @override
  String toString() => 'RefreshToken([redacted])';
}

final class AuthIdentity {
  const AuthIdentity({
    required this.userId,
    required this.email,
    this.platformRole,
    this.tokenId,
  });

  final String userId;
  final String email;
  final String? platformRole;
  final String? tokenId;
}

final class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.expiresAtUtc,
    required this.identity,
    this.refreshToken,
  });

  final String accessToken;
  final DateTime expiresAtUtc;
  final AuthIdentity identity;
  final RefreshToken? refreshToken;

  @override
  String toString() => 'AuthTokens([redacted])';
}

final class RegisteredAccount {
  const RegisteredAccount({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.version,
  });

  final String userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final int version;
}
