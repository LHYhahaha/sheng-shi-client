import 'package:drama_client/bootstrap/feature_session_cleanup.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';
import 'package:drama_client/features/auth/application/auth_controller.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/domain/delete_account_result.dart';
import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cleanup resets auth controller to guest after refresh failed',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
        ],
      );
      addTearDown(container.dispose);
      container.read(featureSessionCleanupRegistrationProvider);

      await container.read(authControllerProvider.notifier).load();
      await container
          .read(authControllerProvider.notifier)
          .login(AuthProviderType.google);
      expect(container.read(authControllerProvider).isLoggedIn, isTrue);

      await container
          .read(sessionCleanupCoordinatorProvider)
          .cleanup(SessionCleanupReason.refreshFailed);

      final auth = container.read(authControllerProvider);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.session.isGuest, isTrue);
      expect(auth.pendingProvider, isNull);
      expect(auth.error, isNull);
      expect(container.read(entitlementControllerProvider).isMember, isFalse);
    },
  );
}

class _SignedInAuthRepository implements AuthRepository {
  AuthSession _session = const AuthSession.guest();

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    _session = AuthSession(
      user: AuthUser(
        id: '1',
        nickname: 'Google User',
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: provider,
      ),
    );
    return _session;
  }

  @override
  Future<AuthSession> logout() async {
    _session = const AuthSession.guest();
    return _session;
  }

  @override
  Future<DeleteAccountResult> deleteAccount() async {
    _session = const AuthSession.guest();
    return DeleteAccountResult(
      session: _session,
      shouldExitApp: true,
    );
  }
}
