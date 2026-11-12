import 'package:flutter_test/flutter_test.dart';
import 'package:ronditrack/app/navigation/auth_redirect.dart';

void main() {
  test('opens sign-in for a signed-out user at Home', () {
    expect(
      authRedirect(location: Uri.parse('/'), signedIn: false),
      signInPath,
    );
    expect(
      authRedirect(location: Uri.parse(signInPath), signedIn: false),
      isNull,
    );
  });

  test('allows a signed-in user to open a protected route', () {
    expect(
      authRedirect(location: Uri.parse('/profile'), signedIn: true),
      isNull,
    );
  });

  test('remembers an invite address through sign-in', () {
    const target = '/join/family-invite';

    final signIn = Uri.parse(
      authRedirect(location: Uri.parse(target), signedIn: false)!,
    );

    expect(signIn.path, signInPath);
    expect(signIn.queryParameters['from'], target);
    expect(authRedirect(location: signIn, signedIn: true), target);
  });

  test('opens Home when a signed-in user opens sign-in directly', () {
    expect(
      authRedirect(location: Uri.parse(signInPath), signedIn: true),
      '/',
    );
  });

  test('drops external and unrecognised return addresses', () {
    for (final target in [
      'https://outside.example/join/family-invite',
      '//outside.example/join/family-invite',
      '/%2Foutside.example',
      '/unknown',
      '/sign-in',
    ]) {
      final location = Uri(
        path: signInPath,
        queryParameters: {'from': target},
      );

      expect(authRedirect(location: location, signedIn: true), '/');
    }
  });
}