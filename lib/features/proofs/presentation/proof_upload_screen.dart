import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';
import 'package:ronditrack/core/state/screen_state.dart';
import 'package:ronditrack/core/widgets/failure_notice.dart';
import 'package:ronditrack/features/proofs/application/proof_providers.dart';
import 'package:ronditrack/features/proofs/application/proof_upload_controller.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

class ProofUploadScreen extends ConsumerWidget {
  const ProofUploadScreen({required this.target, super.key});

  final ProofTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionStateProvider);

    if (state is! AuthSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final settings = ref.watch(proofSettingsProvider);
    final camera = ref.watch(proofCameraAvailableProvider);

    final controller = ref.watch(
      proofControllerProvider((
        userId: state.identity.userId,
        sessionId: state.sessionId,
        stokvelId: target.stokvelId,
        cycleId: target.cycleId,
        contributionId: target.contributionId,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload proof'),
        leading: BackButton(onPressed: () => context.go(target.cycleLocation)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              final photo = controller.photo;
              final failure = controller.failure;
              final stage = controller.stage;

              final canChoose = settings.enabled && !controller.busy;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Choose a clear photo of your proof of payment. '
                    'Check that the details are readable before uploading.',
                  ),
                  const SizedBox(height: 12),
                  if (!settings.enabled)
                    const Text(
                      'Proof uploads are not available on this build.',
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (camera)
                        OutlinedButton.icon(
                          key: const ValueKey('proof-camera'),
                          onPressed: canChoose
                              ? () => unawaited(
                                  controller.choose(ProofSource.camera),
                                )
                              : null,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Take photo'),
                        ),
                      OutlinedButton.icon(
                        key: const ValueKey('proof-gallery'),
                        onPressed: canChoose
                            ? () => unawaited(
                                controller.choose(ProofSource.gallery),
                              )
                            : null,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose photo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (photo != null) ...[
                    Image.memory(
                      photo.bytes,
                      key: const ValueKey('proof-preview'),
                      height: 280,
                      fit: BoxFit.contain,
                      semanticLabel: 'Prepared proof of payment',
                      errorBuilder: (_, _, _) =>
                          const Text('Could not preview this photo.'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Prepared photo: '
                      '${(photo.bytes.length / 1024).ceil()} KB',
                    ),
                    const Text(
                      'Location metadata has been removed '
                      'from this copy.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (controller.busy) ...[
                    LinearProgressIndicator(
                      value: stage == ProofStage.uploading
                          ? controller.progress
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Semantics(
                    liveRegion: true,
                    child: Text(switch (stage) {
                      ProofStage.idle => '',
                      ProofStage.picking => 'Selecting photo…',
                      ProofStage.preparing => 'Preparing photo…',
                      ProofStage.ready => 'Photo ready to upload.',
                      ProofStage.uploading => 'Uploading proof…',
                      ProofStage.uploaded => 'Proof uploaded.',
                      ProofStage.failed => '',
                    }),
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: 12),
                    FailureNotice(
                      state: screenFailure<Object?>(
                        failure,
                        fallback: 'Could not upload this proof.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('proof-upload'),
                    onPressed:
                        settings.enabled &&
                            photo != null &&
                            !controller.busy &&
                            stage != ProofStage.uploaded
                        ? () => unawaited(controller.upload())
                        : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      stage == ProofStage.uploading
                          ? 'Uploading proof…'
                          : 'Upload proof',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
