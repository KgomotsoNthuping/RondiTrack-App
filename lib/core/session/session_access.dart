import 'package:ronditrack/core/result/result.dart';
import 'package:ronditrack/core/session/access_token_store.dart';
import 'package:ronditrack/core/session/auth_state.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';

abstract interface class SessionAccess {
  int get epoch;
  AuthState get state;

  Future<Result<AccessToken>> tokenForRequest();

  Future<Result<AccessToken>> refresh();
}

final class CoordinatorSessionAccess implements SessionAccess {
  new(this._coordinator);

  final SessionCoordinator _coordinator;

  @override
  int get epoch => _coordinator.epoch;

  @override
  AuthState get state => _coordinator.state;

  @override
  Future<Result<AccessToken>> tokenForRequest() =>
      _coordinator.tokenForRequest();

  @override
  Future<Result<AccessToken>> refresh() => _coordinator.refresh();
}
