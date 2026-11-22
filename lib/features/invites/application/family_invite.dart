import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/account_key.dart';
import 'package:ronditrack/core/session/demo_session.dart';

part 'family_invite.g.dart';

const familyInviteCode = 'family-invite';
const familyInviteStokvelId = 'family-savers';
const familyInviteStokvelName = 'Family Savers';

@Riverpod(keepAlive: true, dependencies: [accountKey])
class FamilyInvite extends _$FamilyInvite {
  @override
  bool build() {
    ref.watch(accountKeyProvider);
    return false;
  }

  bool accept(String code) {
    if (ref.read(useApiRepositoriesProvider)) {
      return false;
    }

    final persona = ref.read(demoSessionProvider);

    if (persona == null || code != familyInviteCode) {
      return false;
    }

    if (persona == DemoPersona.naledi) {
      state = true;
    }

    return true;
  }
}
