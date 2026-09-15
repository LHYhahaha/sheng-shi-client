import 'package:drama_client/core/oauth/facebook_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes the payload segment of a Limited Login JWT for logging', () {
    const jwt =
        'eyJhbGciOiJub25lIn0.eyJzdWIiOiJmYWNlYm9vay0xMjMiLCJuYW1lIjoiVGVzdCBVc2VyIn0.signature';

    expect(FacebookOAuthService.decodeJwtPayloadForLogging(jwt), {
      'sub': 'facebook-123',
      'name': 'Test User',
    });
  });
}
