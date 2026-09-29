import 'package:drama_client/core/oauth/facebook_oauth_service.dart';
import 'package:drama_client/core/oauth/oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test('decodes the payload segment of a Limited Login JWT for logging', () {
    const jwt =
        'eyJhbGciOiJub25lIn0.eyJzdWIiOiJmYWNlYm9vay0xMjMiLCJuYW1lIjoiVGVzdCBVc2VyIn0.signature';

    expect(FacebookOAuthService.decodeJwtPayloadForLogging(jwt), {
      'sub': 'facebook-123',
      'name': 'Test User',
    });
  });

  test('maps a LimitedToken to a limited Facebook login credential', () {
    final credential = FacebookOAuthService.facebookLoginCredentialFromToken(
      LimitedToken(
        userId: 'facebook-user',
        userName: 'Test User',
        userEmail: 'test@example.com',
        nonce: 'nonce',
        tokenString: 'limited-login-jwt',
      ),
    );

    expect(credential.token, 'limited-login-jwt');
    expect(credential.type, FacebookLoginCredentialType.limited);
  });

  test('maps a ClassicToken to a classic Facebook login credential', () {
    final credential = FacebookOAuthService.facebookLoginCredentialFromToken(
      ClassicToken(
        declinedPermissions: const [],
        grantedPermissions: const ['email'],
        userId: 'facebook-user',
        expires: DateTime(2030),
        tokenString: 'classic-facebook-access-token',
        applicationId: 'facebook-app',
      ),
    );

    expect(credential.token, 'classic-facebook-access-token');
    expect(credential.type, FacebookLoginCredentialType.classic);
  });

  test(
    'preserves all available Apple fields after native authorization',
    () async {
      final service = FacebookOAuthService(
        requestAppleCredential: () async =>
            const AuthorizationCredentialAppleID(
              userIdentifier: 'apple-user-id',
              givenName: 'Test',
              familyName: 'User',
              email: 'test@example.com',
              authorizationCode: 'apple-authorization-code',
              identityToken: 'apple-identity-token',
              state: null,
            ),
      );

      final credential = await service.signInWithApple();

      expect(credential?.identityToken, 'apple-identity-token');
      expect(credential?.authorizationCode, 'apple-authorization-code');
      expect(credential?.email, 'test@example.com');
      expect(credential?.fullName, 'Test User');
    },
  );
}
