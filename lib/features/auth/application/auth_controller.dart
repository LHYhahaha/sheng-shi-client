import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_provider.dart';
import '../domain/auth_session.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
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

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearFailedAction: true,
    );

    try {
      final session = await ref.read(authRepositoryProvider).fetchSession();
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

    // pendingProvider 同时承担按钮 loading 和并发保护。登录渠道 SDK 往往会弹系统页，
    // 重复点击可能创建多个回调，导致后返回的失败覆盖先成功的 session。
    state = state.copyWith(
      pendingProvider: provider,
      clearError: true,
      clearFailedAction: true,
    );

    try {
      final session = await ref.read(authRepositoryProvider).login(provider);
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearPendingProvider: true,
        clearError: true,
        clearFailedAction: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        failedAction: AuthFailureAction.login,
        clearPendingProvider: true,
      );
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
      final session = await ref.read(authRepositoryProvider).logout();
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
        clearPendingProvider: true,
        clearFailedAction: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        failedAction: AuthFailureAction.logout,
        clearPendingProvider: true,
      );
    }
  }

  Future<void> deleteAccount() async {
    if (state.isLoading) {
      return;
    }

    // 注销账号比 logout 风险更高，但状态处理仍保持一致：只有 repository 返回 guest
    // session 后才认为本地退出成功。
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearFailedAction: true,
    );
    try {
      final session = await ref.read(authRepositoryProvider).deleteAccount();
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
        clearPendingProvider: true,
        clearFailedAction: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        failedAction: AuthFailureAction.deleteAccount,
        clearPendingProvider: true,
      );
    }
  }

  bool _isCurrent(int generation) => generation == _generation;
}
