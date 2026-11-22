import 'package:ronditrack/core/result/result.dart';

const expiredInviteMessage = 'This invite has expired. Ask for a new invite.';

final class InvitePreview {
  const InvitePreview({
    required this.stokvelId,
    required this.name,
    required this.alreadyMember,
  });

  final String stokvelId;
  final String name;
  final bool alreadyMember;
}

final class JoinedInvite {
  const JoinedInvite({required this.stokvelId, required this.name});

  final String stokvelId;
  final String name;
}

abstract interface class InviteRepository {
  Future<Result<InvitePreview>> preview(String code);

  Future<Result<JoinedInvite>> join(String code);
}
