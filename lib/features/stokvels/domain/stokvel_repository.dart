import 'package:ronditrack/features/stokvels/domain/stokvel.dart';

abstract interface class StokvelRepository {
  Future<Stokvel?> fetchDetail(String userId, String stokvelId);
}

abstract interface class StokvelCycleRepository implements StokvelRepository {
  Future<Stokvel?> fetchCycleDetail(
    String userId,
    String stokvelId,
    String cycleId,
  );
}
