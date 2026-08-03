import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account/account_ban_controller.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/auth/auth_refresh_executor_provider.dart';
import '../../../core/auth/session_cleanup_types.dart';
import '../../../core/auth/user_info_manager.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notification/startup_notification_permission_reporter.dart';
import '../../../core/runtime/install_id_provider.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../data/auth_repository_provider.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/delete_account_result.dart';

/// APP 启动时的 token 初始化 provider。
///
/// 流程：
/// 1. 检查是否有已保存的 token
/// 2. 有 token → 尝试刷新 accessToken
/// 3. 刷新失败 → 用 refreshToken 再试一次
/// 4. 都失败 → 调用 loginDevice 获取新 token
/// 5. 调用 AuthController.load() 更新 session 状态
/// 失败不阻断应用启动。
final guestLoginInitializerProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(Duration.zero);
  try {
    print('[TokenInit] Starting token initialization...');
    await ref.read(authControllerProvider.notifier).load();
    print('[TokenInit] ✅ AuthController.load() completed');
  } catch (e, stackTrace) {
    print('[TokenInit] ❌ Token initialization failed: $e');
    print('[TokenInit] Stack trace: $stackTrace');
  }
});

/// Auth feature 的全局 session provider。
///
/// Profile、Account 和 Login 都应该读取这一个 AuthState。不要在 Profile 或 Account
/// 再缓存一份“是否登录”，否则 logout/delete/token 失效后很容易出现页面状态不一致。
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// 三方授权或登录请求没有回调时，避免登录页一直保持 loading。
final thirdPartyLoginTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 1),
);

/// 全局登录态。
///
/// `session` 是唯一可信登录来源，`pendingProvider/failedAction/error` 只是 UI 过程态。
/// Profile、Account 等页面应从 AuthState 合成展示，不要各自缓存“是否登录”，否则
/// logout/delete 后会出现页面状态不同步。
class AuthState {
  const AuthState({
    required this.isLoading,
    required this.session,
    this.pendingProvider,
    this.failedAction,
    this.error,
  });

  const AuthState.initial()
    : isLoading = true,
      session = const AuthSession.guest(),
      pendingProvider = null,
      failedAction = null,
      error = null;

  /// Auth 是否正在执行全局加载或账号动作。
  ///
  /// logout/delete 使用它锁住账号页动作，避免两个破坏性账号操作并发。登录按钮级
  /// loading 另由 `pendingProvider` 表达。
  final bool isLoading;

  /// 当前认证会话。
  ///
  /// 这是登录态唯一来源。guest session 也要显式保存，避免页面用 null 状态自行推断
  /// “尚未加载”和“游客”。
  final AuthSession session;

  /// 当前正在登录的渠道。
  ///
  /// 用于对应按钮 loading 和并发保护。它不是最终登录渠道，最终渠道以 `session.user`
  /// 中 provider 为准。
  final AuthProviderType? pendingProvider;

  /// 最近一次失败的账号动作。
  ///
  /// Account/Auth 页面用它映射具体错误文案。不要只根据 error 是否存在展示统一文案，
  /// logout/delete/login 的用户处理方式不同。
  final AuthFailureAction? failedAction;

  /// 最近一次 auth 操作错误。
  ///
  /// 只用于 UI 错误态和调试，不应该直接向用户展示底层异常文本。
  final Object? error;

  bool get isLoggedIn => session.isLoggedIn;

  AuthUser? get user => session.user;

  AuthState copyWith({
    bool? isLoading,
    AuthSession? session,
    AuthProviderType? pendingProvider,
    AuthFailureAction? failedAction,
    Object? error,
    bool clearPendingProvider = false,
    bool clearFailedAction = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      session: session ?? this.session,
      pendingProvider: clearPendingProvider
          ? null
          : pendingProvider ?? this.pendingProvider,
      failedAction: clearFailedAction
          ? null
          : failedAction ?? this.failedAction,
      error: clearError ? null : error ?? this.error,
    );
  }
}

enum AuthFailureAction { load, login, logout, deleteAccount }

/// Auth 状态机，负责 session 加载、登录、退出和注销账号。
///
/// 所有账号动作都通过 repository provider 进入，UI 不直接调用平台登录或网络层。
/// 这样后续接真实 OAuth、token refresh、账号删除审计时，可以统一处理 loading、
/// error 和 session 清理。
class AuthController extends Notifier<AuthState> {
  int _generation = 0;

  @override
  AuthState build() => const AuthState.initial();

  /// refresh failed / session expired 后回到 guest-safe UI 态（不直接写 token）。
  ///
  /// logout/delete 经 [SessionCleanupAuthRepository] 也会触发 cleanup；此处与 repository
  /// 返回的 guest session 对齐，并清除 pending login/logout/delete 过程态。
  void resetForSessionCleanup(SessionCleanupReason reason) {
    _generation += 1;
    state = const AuthState(
      isLoading: false,
      session: AuthSession.guest(
        sessionId: 'guest-sess-mock',
        guestId: 'guest-mock',
      ),
    );
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearFailedAction: true,
    );

    try {
      await ref.read(installIdProvider.future);
      await ref.read(authTokenStoreProvider.notifier).waitForHydration();
      final tokenStore = ref.read(authTokenStoreProvider);

      if (tokenStore.hasAccessToken &&
          tokenStore.accessToken != null &&
          tokenStore.refreshToken != null) {
        print(
          '[AuthController.load] Found existing token, checking expiration...',
        );

        final now = DateTime.now();
        final accessTokenExpired =
            tokenStore.expiresAt != null && now.isAfter(tokenStore.expiresAt!);
        final refreshTokenExpired =
            tokenStore.refreshExpiresAt != null &&
            now.isAfter(tokenStore.refreshExpiresAt!);

        print(
          '[AuthController.load] Access token expired: $accessTokenExpired, Refresh token expired: $refreshTokenExpired',
        );

        if (!accessTokenExpired) {
          print(
            '[AuthController.load] ✅ Access token still valid, using existing token',
          );

          if (!_isCurrent(generation)) {
            return;
          }

          try {
            final session = await _syncCurrentSession();

            if (!_isCurrent(generation)) {
              return;
            }

            state = state.copyWith(
              isLoading: false,
              session: session,
              clearError: true,
              clearPendingProvider: true,
              clearFailedAction: true,
            );
            _syncNotificationPermission(session);
            return;
          } catch (e) {
            print(
              '[AuthController.load] Current token sync failed, falling back to device login: $e',
            );
          }
        }

        if (!refreshTokenExpired) {
          print(
            '[AuthController.load] Access token expired, attempting to refresh with refresh token...',
          );

          try {
            final refreshed = await ref.read(authRefreshExecutorProvider)(
              tokenStore.refreshToken!,
              currentToken: tokenStore,
            );

            if (refreshed != null && refreshed.hasAccessToken) {
              print('[AuthController.load] ✅ Token refresh successful');
              await ref.read(authTokenStoreProvider.notifier).save(refreshed);

              if (!_isCurrent(generation)) {
                return;
              }

              try {
                final session = await _syncCurrentSession();

                if (!_isCurrent(generation)) {
                  return;
                }

                state = state.copyWith(
                  isLoading: false,
                  session: session,
                  clearError: true,
                  clearPendingProvider: true,
                  clearFailedAction: true,
                );
                _syncNotificationPermission(session);
                return;
              } catch (e) {
                print(
                  '[AuthController.load] Refreshed token sync failed, falling back to device login: $e',
                );
              }
            }
          } catch (e) {
            print('[AuthController.load] ⚠️ Token refresh failed: $e');
          }
        } else {
          print(
            '[AuthController.load] Refresh token also expired, need to re-login',
          );
        }

        print(
          '[AuthController.load] Token refresh failed or refresh token expired, falling back to device login...',
        );
      } else {
        print(
          '[AuthController.load] No existing token found, performing device login...',
        );
      }

      // 没有 token 或都失败 → 调用 device login 获取新 token 和用户信息
      print('[AuthController.load] Calling login(AuthProviderType.device)...');
      final repositorySession = await ref
          .read(authRepositoryProvider)
          .login(AuthProviderType.device);

      if (!_isCurrent(generation)) {
        return;
      }

      final session = await _syncCurrentSession(
        fallbackProvider: AuthProviderType.device,
        fallbackSession: repositorySession,
      );

      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
        clearPendingProvider: true,
        clearFailedAction: true,
      );
      _syncNotificationPermission(session);
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: error,
        failedAction: AuthFailureAction.load,
      );
    }
  }

  Future<void> login(AuthProviderType provider) async {
    if (state.pendingProvider != null) {
      return;
    }

    state = state.copyWith(
      pendingProvider: provider,
      clearError: true,
      clearFailedAction: true,
    );

    try {
      await ref.read(installIdProvider.future);
      // 调用 repository 的 login 方法，会自动获取 token 和用户信息
      final login = ref.read(authRepositoryProvider).login(provider);
      final repositorySession = switch (provider) {
        AuthProviderType.google || AuthProviderType.facebook =>
          await login.timeout(ref.read(thirdPartyLoginTimeoutProvider)),
        AuthProviderType.device => await login,
      };

      final session = await _syncCurrentSession(
        fallbackProvider: provider,
        fallbackSession: repositorySession,
      );

      state = state.copyWith(
        isLoading: false,
        session: session,
        clearPendingProvider: true,
        clearError: true,
        clearFailedAction: true,
      );
      _syncNotificationPermission(session);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        failedAction: AuthFailureAction.login,
        clearPendingProvider: true,
      );
    }
  }

  /// 封禁反馈页返回后的恢复流程：优先用现有 token 校验权益，只有认证失效时
  /// 才按保存的登录渠道重新认证。
  Future<bool> recoverAfterAccountBan() async {
    try {
      await ref
          .read(entitlementControllerProvider.notifier)
          .verifyAccountStatusOrThrow();
      ref.read(accountBanControllerProvider.notifier).clearAfterVerification();
      return true;
    } on ApiException catch (error) {
      final hasAccessToken = ref.read(authTokenStoreProvider).hasAccessToken;
      if (!error.isAuthFailure && hasAccessToken) {
        return false;
      }
    } catch (_) {
      return false;
    }

    return _reauthenticateAndVerifyAfterAccountBan();
  }

  Future<bool> _reauthenticateAndVerifyAfterAccountBan() async {
    if (state.pendingProvider != null) {
      return false;
    }

    final generation = ++_generation;
    await ref.read(authTokenStoreProvider.notifier).waitForHydration();
    final token = ref.read(authTokenStoreProvider);
    final provider =
        _providerFromToken(token.provider) ??
        state.user?.provider ??
        AuthProviderType.device;

    state = state.copyWith(
      isLoading: true,
      pendingProvider: provider,
      clearError: true,
      clearFailedAction: true,
    );

    try {
      final repositorySession = await ref
          .read(authRepositoryProvider)
          .login(provider);
      if (!_isCurrent(generation)) {
        return false;
      }

      // repository.login 已完成用户资料请求；这里只补一次权益校验，避免重复拉取资料。
      await ref
          .read(entitlementControllerProvider.notifier)
          .verifyAccountStatusOrThrow();
      if (!_isCurrent(generation)) {
        return false;
      }

      final session = await _sessionFromCurrentStores(
        fallbackProvider: provider,
        fallbackSession: repositorySession,
      );
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearPendingProvider: true,
        clearError: true,
        clearFailedAction: true,
      );
      _syncNotificationPermission(session);
      ref.read(accountBanControllerProvider.notifier).clearAfterVerification();
      return true;
    } catch (error) {
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isLoading: false,
          error: error,
          failedAction: AuthFailureAction.login,
          clearPendingProvider: true,
        );
      }
      return false;
    }
  }

  Future<void> logout() async {
    if (state.isLoading) {
      return;
    }

    // logout/delete 共用 isLoading 锁，避免账号操作交叉执行。失败时保留原 session，
    // 让用户仍可重试，而不是把本地状态清成半登录。
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearFailedAction: true,
    );
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.logout();
      final repositorySession = await repository.login(AuthProviderType.device);
      final session = await _syncCurrentSession(
        fallbackProvider: AuthProviderType.device,
        fallbackSession: repositorySession,
      );
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
        clearPendingProvider: true,
        clearFailedAction: true,
      );
      _syncNotificationPermission(session);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        failedAction: AuthFailureAction.logout,
        clearPendingProvider: true,
      );
    }
  }

  Future<DeleteAccountResult?> deleteAccount() async {
    if (state.isLoading) {
      return null;
    }

    // 注销账号比 logout 风险更高，但状态处理仍保持一致：只有 repository 返回 guest
    // session 后才认为本地退出成功。
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearFailedAction: true,
    );
    try {
      final repository = ref.read(authRepositoryProvider);
      final result = await repository.deleteAccount();

      final session = result.shouldExitApp
          ? result.session
          : await _loginDeviceAfterAccountDeletion(repository);

      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
        clearPendingProvider: true,
        clearFailedAction: true,
      );

      return result;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        failedAction: AuthFailureAction.deleteAccount,
        clearPendingProvider: true,
      );
      return null;
    }
  }

  Future<AuthSession> _loginDeviceAfterAccountDeletion(
    AuthRepository repository,
  ) async {
    final repositorySession = await repository.login(AuthProviderType.device);
    final session = await _syncCurrentSession(
      fallbackProvider: AuthProviderType.device,
      fallbackSession: repositorySession,
    );
    if (session.user?.provider == AuthProviderType.device) {
      return AuthSession.guest(
        sessionId: session.sessionId,
        guestId: session.guestId,
      );
    }
    return session;
  }

  void _syncNotificationPermission(AuthSession session) {
    // 后端将静默登录与正式登录的同一 showId 视为同一账号；没有 showId 不同步。
    final showId =
        session.user?.showId ?? ref.read(userInfoStoreProvider).showId;
    unawaited(
      ref
          .read(startupNotificationPermissionReporterProvider)
          .syncForAccount(showId),
    );
  }

  bool _isCurrent(int generation) => generation == _generation;

  Future<AuthSession> _syncCurrentSession({
    AuthProviderType fallbackProvider = AuthProviderType.device,
    AuthSession? fallbackSession,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    if (repository is! CurrentAuthSessionSynchronizer) {
      return fallbackSession ?? const AuthSession.guest();
    }
    final synchronizer = repository as CurrentAuthSessionSynchronizer;

    final token = ref.read(authTokenStoreProvider);
    if (!token.hasAccessToken) {
      return fallbackSession ?? const AuthSession.guest();
    }

    final candidate = await synchronizer.syncCurrentSession();
    final isEntitlementVerified = await ref
        .read(entitlementControllerProvider.notifier)
        .load();
    if (isEntitlementVerified) {
      ref.read(accountBanControllerProvider.notifier).clearAfterVerification();
    }
    return _sessionFromCurrentStores(
      fallbackProvider: fallbackProvider,
      fallbackSession: candidate,
    );
  }

  Future<AuthSession> _sessionFromCurrentStores({
    required AuthProviderType fallbackProvider,
    AuthSession? fallbackSession,
  }) async {
    final syncedToken = ref.read(authTokenStoreProvider);

    final provider =
        _providerFromToken(syncedToken.provider) ?? fallbackProvider;
    if (syncedToken.sessionKind != AuthTokenSessionKind.authenticated) {
      return AuthSession.guest(
        sessionId: syncedToken.subjectId,
        guestId: syncedToken.guestId,
      );
    }

    await ref.read(userInfoStoreProvider.notifier).waitForHydration();
    final userInfoStore = ref.read(userInfoStoreProvider);
    if (userInfoStore.hasUserInfo) {
      return UserInfoManager.buildSessionFromUserInfo(
        userInfoStore,
        provider: provider,
      );
    }
    return fallbackSession ?? const AuthSession.guest();
  }

  AuthProviderType? _providerFromToken(String? value) {
    return switch (value) {
      'facebook' => AuthProviderType.facebook,
      'google' => AuthProviderType.google,
      'device' => AuthProviderType.device,
      _ => null,
    };
  }
}
