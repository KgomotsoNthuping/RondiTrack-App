import 'package:ronditrack/features/stokvels/domain/stokvel.dart';

/// Loads a stokvel for the signed-in member.
abstract interface class StokvelRepository {
  /// Returns null when [stokvelId] is missing or outside [userId]'s memberships.
  Future<Stokvel?> fetchDetail(String userId, String stokvelId);
}