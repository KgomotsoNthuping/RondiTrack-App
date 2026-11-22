import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ronditrack/app/provider_retry.dart';
import 'package:ronditrack/core/config/repository_mode_provider.dart';
import 'package:ronditrack/core/session/account_key.dart';
import 'package:ronditrack/core/session/session_coordinator.dart';
import 'package:ronditrack/core/session/session_coordinator_provider.dart';

class AccountScope extends ConsumerStatefulWidget {
  const AccountScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AccountScope> createState() => _AccountScopeState();
}

class _AccountScopeState extends ConsumerState<AccountScope> {
  ProviderContainer? _container;
  ProviderContainer? _parent;
  SessionCoordinator? _session;
  AccountKey? _account;

  ProviderContainer _createContainer() {
    return ProviderContainer(
      parent: _parent,
      retry: appProviderRetry,
      overrides: [accountKeyProvider.overrideWith(accountKey)],
    );
  }

  void _sessionChanged() {
    final next = accountFromState(_session!.state);

    if (next == _account) {
      return;
    }

    final previous = _container;

    setState(() {
      _account = next;
      _container = _createContainer();
    });

    previous?.dispose();
  }

  void _detach() {
    _session?.removeListener(_sessionChanged);
    _container?.dispose();

    _container = null;
    _parent = null;
    _session = null;
    _account = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(useApiRepositoriesProvider)) {
      _detach();
      return widget.child;
    }

    final parent = ProviderScope.containerOf(context, listen: false);

    final session = ref.watch(sessionCoordinatorProvider);

    if (!identical(parent, _parent) || !identical(session, _session)) {
      _detach();

      _parent = parent;
      _session = session;
      _account = accountFromState(session.state);
      _container = _createContainer();

      session.addListener(_sessionChanged);
    }

    return UncontrolledProviderScope(
      key: ValueKey(_container),
      container: _container!,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}
