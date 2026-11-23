const signInPath = '/sign-in';
const registerPath = '/register';
const splashPath = '/splash';

String? authRedirect({
  required Uri location,
  required bool signedIn,
  bool restoring = false,
  String? appLinkScheme,
}) {
  if (location.hasScheme || location.hasAuthority) {
    final target = _nativeReturnAddress(location, appLinkScheme);

    if (restoring) {
      return _splashLocation(target);
    }

    return signedIn ? target ?? '/' : _authLocation(signInPath, target);
  }

  final atSignIn = location.path == signInPath;
  final atRegister = location.path == registerPath;
  final atSplash = location.path == splashPath;
  final atAuth = atSignIn || atRegister || atSplash;

  String? target;

  try {
    target = _returnAddress(
      atAuth ? location.queryParameters['from'] : location.toString(),
    );
  } on FormatException {
    target = null;
  }

  if (restoring) {
    return atSplash
        ? null
        : _splashLocation(
            target,
            auth: atRegister
                ? 'register'
                : atSignIn
                ? 'sign-in'
                : null,
            email: atSignIn ? location.queryParameters['email'] : null,
          );
  }

  if (signedIn) {
    return atAuth ? target ?? '/' : null;
  }

  if (atSignIn || atRegister) {
    return null;
  }

  if (atSplash) {
    return _authLocation(
      location.queryParameters['auth'] == 'register'
          ? registerPath
          : signInPath,
      target,
      email: location.queryParameters['email'],
    );
  }

  return _authLocation(signInPath, target);
}

String _authLocation(String path, String? target, {String? email}) {
  final parameters = <String, String>{
    if (target != null && target != '/') 'from': target,
    if (email != null && email.isNotEmpty) 'email': email,
  };

  return parameters.isEmpty
      ? path
      : Uri(path: path, queryParameters: parameters).toString();
}

String _splashLocation(String? target, {String? auth, String? email}) {
  final parameters = <String, String>{
    if (target != null && target != '/') 'from': target,
    'auth': ?auth,
    if (email != null && email.isNotEmpty) 'email': email,
  };

  return parameters.isEmpty
      ? splashPath
      : Uri(path: splashPath, queryParameters: parameters).toString();
}

String? _nativeReturnAddress(Uri location, String? appLinkScheme) {
  if (appLinkScheme == null ||
      location.scheme != appLinkScheme ||
      location.host != 'app' ||
      location.userInfo.isNotEmpty ||
      location.hasPort ||
      location.hasFragment) {
    return null;
  }

  final path = location.path;

  if (!path.startsWith('/stokvels/') && !path.startsWith('/join/')) {
    return null;
  }

  return _returnAddress(location.hasQuery ? '$path?${location.query}' : path);
}

String? _returnAddress(String? value) {
  if (value == null ||
      !value.startsWith('/') ||
      value.startsWith('//') ||
      value.contains(r'\')) {
    return null;
  }

  try {
    final uri = Uri.parse(value);

    if (uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
      return null;
    }

    if (uri.path == '/') {
      return uri.toString();
    }

    final segments = uri.pathSegments;

    if (segments.any(
      (part) =>
          part.isEmpty ||
          part == '.' ||
          part == '..' ||
          part.contains('/') ||
          part.contains(r'\'),
    )) {
      return null;
    }

    return switch (segments) {
      ['stokvels'] ||
      ['activity'] ||
      ['profile'] ||
      ['stokvels', _] ||
      ['stokvels', _, 'cycles', _] ||
      ['stokvels', _, 'cycles', _, 'payouts'] ||
      ['join', _] => uri.toString(),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}
