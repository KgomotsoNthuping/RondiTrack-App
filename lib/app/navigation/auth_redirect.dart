const signInPath = '/sign-in';

String? authRedirect({
  required Uri location,
  required bool signedIn,
}) {
  final atSignIn = location.path == signInPath;

  if (!signedIn) {
    if (atSignIn) {
      return null;
    }

    final target = _returnAddress(location.toString());
    if (target == null || target == '/') {
      return signInPath;
    }

    return Uri(
      path: signInPath,
      queryParameters: {'from': target},
    ).toString();
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