import 'package:drama_client/core/oauth/facebook_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
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
