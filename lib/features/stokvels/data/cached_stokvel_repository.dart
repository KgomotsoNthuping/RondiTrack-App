import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_repository.dart';

final class CachedStokvelRepository implements StokvelRepository {
  new(this._fetch);

  final Future<Stokvel> Function(String, String) _fetch;

  @override
  Future<Stokvel?> fetchDetail(String userId, String stokvelId) {
    return _fetch(userId, stokvelId);
  }
}
