import 'package:drama_client/core/oauth/oauth_service.dart';
import 'package:drama_client/features/auth/data/dto/oauth_login_request_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Facebook limited login sends only the authentication token', () {
    final request = OAuthLoginRequestDto.facebook(
      FacebookLoginCredential.limited('limited-login-jwt'),
    );

    expect(request.toJson(), {'authenticationToken': 'limited-login-jwt'});
  });

  test('Facebook classic login sends only the Facebook access token', () {
    final request = OAuthLoginRequestDto.facebook(
      FacebookLoginCredential.classic('classic-facebook-access-token'),
    );

    expect(request.toJson(), {
      'facebookToken': 'classic-facebook-access-token',
    });
  });
}
