import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/core/network/data/api_transport_provider.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/features/proofs/application/proof_upload_controller.dart';
import 'package:ronditrack/features/proofs/data/dio_proof_uploader.dart';
import 'package:ronditrack/features/proofs/data/image_proof_picker.dart';
import 'package:ronditrack/features/proofs/data/image_proof_preparer.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

final proofSettingsProvider = Provider<ProofSettings>(
  (ref) => ProofSettings.fromEnvironment(),
);

final proofPickerProvider = Provider<ProofPicker>((ref) => ImageProofPicker());

final proofPreparerProvider = Provider<ProofPreparer>(
  (ref) => const ImageProofPreparer(),
);

final proofCameraAvailableProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

typedef ProofKey = ({
  String userId,
  int sessionId,
  String stokvelId,
  String cycleId,
  String contributionId,
});

final proofControllerProvider = Provider.autoDispose
    .family<ProofUploadController, ProofKey>(
      (ref, key) {
        final session = ref.watch(sessionCoordinatorProvider);

        final settings = ref.watch(proofSettingsProvider);

        bool isCurrent() {
          final state = session.state;

          return state is AuthSignedIn &&
              state.identity.userId == key.userId &&
              state.sessionId == key.sessionId &&
              session.epoch == key.sessionId;
        }

        final controller = ProofUploadController(
          target: ProofTarget.parse(
            stokvelId: key.stokvelId,
            cycleId: key.cycleId,
            contributionId: key.contributionId,
          )!,
          settings: settings,
          picker: ref.watch(proofPickerProvider),
          preparer: ref.watch(proofPreparerProvider),
          uploader: DioProofUploader(() => ref.read(apiDioProvider), settings),
          isCurrent: isCurrent,
        );

        ref.listen(sessionStateProvider, (_, _) {
          if (!isCurrent()) {
            controller.invalidate();
          }
        });

        ref.onDispose(controller.dispose);

        return controller;
      },
      dependencies: [
        sessionCoordinatorProvider,
        sessionStateProvider,
        apiDioProvider,
        proofSettingsProvider,
        proofPickerProvider,
        proofPreparerProvider,
      ],
    );
