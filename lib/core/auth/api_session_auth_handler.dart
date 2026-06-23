import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale/app_locale_controller.dart';
import '../network/api_client.dart';
import '../toast/app_toast_provider.dart';
import 'auth_refresh_coordinator.dart';
import 'auth_refresh_executor_provider.dart';
import 'auth_token_store.dart';
import 'session_cleanup_coordinator.dart';

final apiSessionAuthHandlerProvider =
    Provider.family<ApiSessionAuthHandler, ApiClient>((ref, apiClient) {
      return ApiSessionAuthHandler(
        refreshCoordinator: ref.watch(authRefreshCoordinatorProvider),
        tokenStore: ref.read(authTokenStoreProvider.notifier),
        readToken: () => ref.read(authTokenStoreProvider),
        sessionCleanup: ref.watch(sessionCleanupCoordinatorProvider),
        refreshExecutor: createAuthRefreshExecutor(apiClient),
        onSessionExpired: () async {
          _showSessionExpiredToast(ref);
        },
        onGuestSessionExpired: () async {
          _showSessionExpiredToast(ref);
          await Future<void>.delayed(const Duration(milliseconds: 800));
          await SystemNavigator.pop();
        },
      );
    });

void _showSessionExpiredToast(Ref ref) {
  final locale = ref.read(appLocaleControllerProvider);
  final message = locale.languageCode == 'zh'
      ? '\u767b\u5f55\u8fc7\u671f'
      : 'Session expired';
  ref.read(appToastProvider).warning(message);
}

/// Coordinates API-triggered auth refresh and session cleanup.
class ApiSessionAuthHandler {
  ApiSessionAuthHandler({
    required AuthRefreshCoordinator refreshCoordinator,
    required AuthTokenStore tokenStore,
    required AuthTokenSnapshot Function() readToken,
    required SessionCleanupCoordinator sessionCleanup,
    required AuthRefreshExecutor refreshExecutor,
    Future<void> Function()? onSessionExpired,
    Future<void> Function()? onGuestSessionExpired,
  }) : _refreshCoordinator = refreshCoordinator,
       _tokenStore = tokenStore,
       _readToken = readToken,
       _sessionCleanup = sessionCleanup,
       _refreshExecutor = refreshExecutor,
       _onSessionExpired = onSessionExpired,
       _onGuestSessionExpired = onGuestSessionExpired;

  final AuthRefreshCoordinator _refreshCoordinator;
  final AuthTokenStore _tokenStore;
  final AuthTokenSnapshot Function() _readToken;
  final SessionCleanupCoordinator _sessionCleanup;
  final AuthRefreshExecutor _refreshExecutor;
  final Future<void> Function()? _onSessionExpired;
  final Future<void> Function()? _onGuestSessionExpired;
  Future<void>? _sessionExpiredInFlight;

  /// Handles 401 responses by refreshing access tokens when possible.
  Future<bool> handleUnauthorized() async {
    final current = _readToken();
    final refreshToken = current.refreshToken;
    final refreshExpiresAt = current.refreshExpiresAt;

    print('[ApiSessionAuthHandler] handleUnauthorized called');
    print(
      '[ApiSessionAuthHandler]   hasRefreshToken: ${refreshToken != null && refreshToken.isNotEmpty}',
    );
    print('[ApiSessionAuthHandler]   refreshExpiresAt: $refreshExpiresAt');

    if (refreshToken == null || refreshToken.isEmpty) {
      print(
        '[ApiSessionAuthHandler] No refreshToken available, cleaning up session',
      );
      await _sessionCleanup.cleanup(SessionCleanupReason.sessionExpired);
      return false;
    }

    final now = DateTime.now();
    if (refreshExpiresAt != null && now.isAfter(refreshExpiresAt)) {
      print(
        '[ApiSessionAuthHandler] refreshToken expired at $refreshExpiresAt, cleaning up session',
      );
      await _sessionCleanup.cleanup(SessionCleanupReason.sessionExpired);
      return false;
    }

    try {
      print(
        '[ApiSessionAuthHandler] Attempting to refresh accessToken with refreshToken',
      );
      final refreshed = await _refreshCoordinator.refresh(
        () => _refreshExecutor(refreshToken, currentToken: current),
      );

      if (refreshed == null || !refreshed.hasAccessToken) {
        print(
          '[ApiSessionAuthHandler] Token refresh returned invalid result, cleaning up session',
        );
        await _sessionCleanup.cleanup(SessionCleanupReason.refreshFailed);
        return false;
      }

      print(
        '[ApiSessionAuthHandler] Token refresh successful, saving new token',
      );
      await _tokenStore.save(refreshed);
      return true;
    } catch (e) {
      print(
        '[ApiSessionAuthHandler] Token refresh failed with error: $e, cleaning up session',
      );
      await _sessionCleanup.cleanup(SessionCleanupReason.refreshFailed);
      return false;
    }
  }

  Future<void> handleSessionInvalidated() {
    return _sessionCleanup.cleanup(SessionCleanupReason.sessionExpired);
  }

  Future<bool> handleSessionExpiredBusinessCode() async {
    final current = _readToken();
    _sessionExpiredInFlight ??= _handleSessionExpiredOnce(current)
        .catchError((Object error, StackTrace stackTrace) {
          print(
            '[ApiSessionAuthHandler] session expired handler failed: '
            '$error',
          );
        })
        .whenComplete(() {
          _sessionExpiredInFlight = null;
        });
    await _sessionExpiredInFlight;
    return true;
  }

  Future<void> _handleSessionExpiredOnce(AuthTokenSnapshot current) async {
    if (current.sessionKind == AuthTokenSessionKind.guest) {
      await _sessionCleanup.cleanup(
        SessionCleanupReason.guestSessionExpiredExit,
      );
      await _onGuestSessionExpired?.call();
      return;
    }

    await _sessionCleanup.cleanup(SessionCleanupReason.logout);
    await _onSessionExpired?.call();
  }
}
