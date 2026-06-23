import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/auth/data/dto/auth_session_dto.dart';
import 'package:drama_client/features/auth/data/dto/auth_token_dto.dart';
import 'package:drama_client/features/auth/data/dto/user_info_dto.dart';
import 'package:drama_client/features/auth/data/mapper/auth_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tokenJson = {
    'accessToken': 'access',
    'refreshToken': 'refresh',
    'tokenType': 'Bearer',
  };

  const userJson = {
    'userId': 'user-1',
    'nickname': 'User',
    'provider': 'google',
    'isGuest': false,
  };

  test('missing accessToken throws', () {
    expect(
      () => AuthTokenDto.fromJson({'refreshToken': 'refresh'}),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('authenticated session without token throws', () {
    expect(
      () => AuthSessionDto.fromJson({
        'isAuthenticated': true,
        'isNewUser': false,
        'user': userJson,
      }),
      throwsA(
        isA<ApiMappingException>().having((e) => e.field, 'field', 'token'),
      ),
    );
  });

  test('malformed session payload throws instead of guest coercion', () {
    expect(
      () => AuthSessionDto.fromJson('malformed'),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('valid session maps to authenticated domain', () {
    final session = const AuthMapper().mapSession(
      AuthSessionDto.fromJson({
        'isAuthenticated': true,
        'isNewUser': false,
        'user': userJson,
        'token': tokenJson,
      }),
    );

    expect(session.isLoggedIn, isTrue);
    expect(session.user?.id, 'user-1');
  });

  test('guest session maps to guest domain', () {
    final session = const AuthMapper().mapSession(
      AuthSessionDto.fromJson({
        'isAuthenticated': false,
        'isNewUser': false,
        'user': null,
        'token': null,
      }),
    );

    expect(session.isLoggedIn, isFalse);
  });

  test('user info accepts avatar url aliases', () {
    final camelCase = UserInfoDto.fromJson({
      'showId': '10001',
      'nickname': 'Guest',
      'avatarUrl': 'https://cdn.example.com/avatar-camel.jpg',
    });
    final snakeCase = UserInfoDto.fromJson({
      'showId': '10002',
      'nickname': 'Guest',
      'avatar_url': 'https://cdn.example.com/avatar-snake.jpg',
    });

    expect(camelCase.avatar, 'https://cdn.example.com/avatar-camel.jpg');
    expect(snakeCase.avatar, 'https://cdn.example.com/avatar-snake.jpg');
  });
}
