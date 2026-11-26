import 'package:flutter/foundation.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

enum ProofStage { idle, picking, preparing, ready, uploading, uploaded, failed }

final class ProofUploadController extends ChangeNotifier {
  ProofUploadController({
    required this.target,
    required this.settings,
    required this.picker,
    required this.preparer,
    required this.uploader,
    required bool Function() isCurrent,
  }) : _isCurrent = isCurrent;

  final ProofTarget target;
  final ProofSettings settings;
  final ProofPicker picker;
  final ProofPreparer preparer;
  final ProofUploader uploader;
  final bool Function() _isCurrent;

  ProofStage stage = ProofStage.idle;
  PreparedProof? photo;
  Failure? failure;
  String? proofId;
  double? progress;

  bool _closed = false;
  int _generation = 0;

  bool get busy =>
      stage == ProofStage.picking ||
      stage == ProofStage.preparing ||
      stage == ProofStage.uploading;

  bool _current(int generation) =>
      !_closed && generation == _generation && _isCurrent();

  Future<void> choose(ProofSource source) async {
    if (busy || _closed || !_isCurrent() || !settings.enabled) {
      return;
    }

    final generation = ++_generation;

    photo = null;
    failure = null;
    proofId = null;
    progress = null;
    stage = ProofStage.picking;

    notifyListeners();

    try {
      final bytes = await picker.pick(source);

      if (!_current(generation)) {
        return;
      }

      if (bytes == null) {
        stage = ProofStage.idle;
        notifyListeners();
        return;
      }

      stage = ProofStage.preparing;
      notifyListeners();

      final prepared = await preparer.prepare(bytes, settings.maxBytes);

      if (!_current(generation)) {
        return;
      }

      photo = prepared;
      stage = ProofStage.ready;

      notifyListeners();
    } on Object catch (error) {
      if (_current(generation)) {
        failure = error is Failure ? error : mapFailure(error, isRead: false);

        stage = ProofStage.failed;
        notifyListeners();
      }
    }
  }

  Future<void> upload() async {
    final selected = photo;

    if (busy ||
        _closed ||
        !_isCurrent() ||
        !settings.enabled ||
        selected == null ||
        stage == ProofStage.uploaded) {
      return;
    }

    final generation = ++_generation;

    failure = null;
    progress = null;
    stage = ProofStage.uploading;

    notifyListeners();

    try {
      final id = await uploader.upload(
        target,
        selected,
        onProgress: (sent, total) {
          if (_current(generation) && total > 0) {
            progress = (sent / total).clamp(0.0, 1.0).toDouble();

            notifyListeners();
          }
        },
      );

      if (!_current(generation)) {
        return;
      }

      proofId = id;
      photo = null;
      stage = ProofStage.uploaded;

      notifyListeners();
    } on Object catch (error) {
      if (_current(generation)) {
        failure = error is Failure ? error : mapFailure(error, isRead: false);

        stage = ProofStage.failed;
        notifyListeners();
      }
    }
  }

  void invalidate() {
    if (_closed) {
      return;
    }

    _generation++;
    uploader.cancel();

    photo = null;
    proofId = null;
    failure = null;
    progress = null;
    stage = ProofStage.idle;

    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;

    uploader.cancel();

    photo = null;
    proofId = null;

    super.dispose();
  }
}
