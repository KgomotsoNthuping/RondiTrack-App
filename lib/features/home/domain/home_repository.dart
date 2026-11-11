import 'package:ronditrack/features/home/domain/home_entry.dart';

abstract interface class HomeRepository {
  Future<List<HomeEntry>> fetchHome(String userId);
}
