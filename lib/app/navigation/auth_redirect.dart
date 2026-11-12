const signInPath = '/sign-in';

String? authRedirect({
  required Uri location,
  required bool signedIn,
  String? appLinkScheme,
}) {
  if (location.hasScheme || location.hasAuthority) {
    final target = _nativeReturnAddress(location, appLinkScheme);
    return signedIn ? target ?? '/' : _signInLocation(target);
  }

  final atSignIn = location.path == signInPath;

  if (!signedIn) {
    return atSignIn ? null : _signInLocation(_returnAddress(location.toString()));
  }

  if (!atSignIn) {
    return null;
  }

  try {
    return _returnAddress(location.queryParameters['from']) ?? '/';
  } on FormatException {
    return '/';
  }
}

String _signInLocation(String? target) {
  if (target == null || target == '/') {
    return signInPath;
  }

  return Uri(
    path: signInPath,
    queryParameters: {'from': target},
  ).toString();
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

  final target = location.hasQuery ? '$path?${location.query}' : path;
  return _returnAddress(target);
}

String? _returnAddress(String? value) {
  if (value == null ||
      !value.startsWith('/') ||
      value.startsWith('//') ||
      value.contains('\\')) {
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
      (segment) =>
          segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          segment.contains('/') ||
          segment.contains('\\'),
    )) {
      return null;
    }

    return switch (segments) {
      ['stokvels'] ||
      ['activity'] ||
      ['profile'] ||
      ['stokvels', _] ||
      ['stokvels', _, 'cycles', _] ||
      ['join', _] => uri.toString(),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}