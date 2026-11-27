import 'package:dio/dio.dart';
import 'package:ronditrack/core/errors/failure.dart';
import 'package:ronditrack/core/network/data/failure_mapper.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';

final class DioProofUploader implements ProofUploader {
  new(this._readDio, this.settings);

  final Dio Function() _readDio;
  final ProofSettings settings;

  CancelToken? _cancel;

  @override
  Future<String> upload(
    ProofTarget target,
    PreparedProof photo, {
    required void Function(int sent, int total) onProgress,
  }) async {
    if (!settings.enabled || settings.maxBytes <= 0) {
      throw const RuleFailure(detail: 'Proof uploads are unavailable.');
    }

    if (photo.bytes.isEmpty || photo.bytes.length > settings.maxBytes) {
      throw const RuleFailure(
        detail: 'The prepared photo exceeds the upload limit.',
      );
    }

    if (_cancel != null) {
      throw const RuleFailure(detail: 'A proof is already uploading.');
    }

    final cancel = CancelToken();
    _cancel = cancel;

    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          photo.bytes,
          filename: 'proof.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });

      final response = await _readDio().post<Object?>(
        target.uploadPath,
        data: form,
        cancelToken: cancel,
        onSendProgress: onProgress,
        options: Options(followRedirects: false),
      );

      if (response.statusCode != 201) {
        throw ServerFailure(correlationId: responseCorrelationId(response));
      }

      final data = response.data;

      final id = data is Map<String, dynamic> ? data['proofId'] : null;

      if (id is! String || !ProofTarget.validId(id)) {
        throw ServerFailure(correlationId: responseCorrelationId(response));
      }

      return id.toLowerCase();
    } on DioException catch (error) {
      if (error.response?.statusCode == 413) {
        throw ValidationFailure(
          errors: const {},
          detail:
              'The server upload limit was exceeded. '
              'Choose a smaller photo.',
          correlationId: responseCorrelationId(error.response),
        );
      }

      throw mapFailure(error, isRead: false);
    } on Object catch (error) {
      throw mapFailure(error, isRead: false);
    } finally {
      if (identical(_cancel, cancel)) {
        _cancel = null;
      }
    }
  }

  @override
  void cancel() => _cancel?.cancel('Session or screen changed');
}
