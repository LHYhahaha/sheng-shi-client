import 'auth_session.dart';

abstract interface class AuthRepository {
  Future<AuthSession> fetchSession();

  Future<AuthSession> login(AuthProviderType provider);

  Future<AuthSession> logout();

  Future<AuthSession> deleteAccount();
}
