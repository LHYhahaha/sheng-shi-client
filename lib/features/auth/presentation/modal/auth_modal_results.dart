import '../../../../core/modal/app_modal_result.dart';
import '../../domain/auth_session.dart';

/// Auth 登录弹窗 typed result（feature 层）；底层序列化为 [LoginModalResult]。
sealed class AuthLoginModalResult {
  const AuthLoginModalResult();

  const factory AuthLoginModalResult.success({
    required AuthProviderType provider,
    required AuthUser user,
    bool accountLinked,
  }) = AuthLoginModalSuccess;

  const factory AuthLoginModalResult.cancelled() = AuthLoginModalCancelled;

  const factory AuthLoginModalResult.dismissed() = AuthLoginModalDismissed;

  const factory AuthLoginModalResult.failed() = AuthLoginModalFailed;

  factory AuthLoginModalResult.fromAppModalResult(AppModalResult result) {
    if (result is! LoginModalResult) {
      return const AuthLoginModalResult.dismissed();
    }
    return switch (result.kind) {
      AppModalResultKind.completed => AuthLoginModalSuccess(
        provider: AuthProviderType.values.byName(result.provider!),
        user: AuthUser(
          userId: result.userId!,
          nickname: result.userNickname!,
          avatarAssetPath: authDefaultAvatarAssetPath,
          provider: AuthProviderType.values.byName(result.provider!),
        ),
        accountLinked: result.accountLinked,
      ),
      AppModalResultKind.cancelled => const AuthLoginModalResult.cancelled(),
      AppModalResultKind.dismissed => const AuthLoginModalResult.dismissed(),
      AppModalResultKind.failed => const AuthLoginModalResult.failed(),
    };
  }

  LoginModalResult toLoginModalResult();

  bool get isSuccess => this is AuthLoginModalSuccess;

  bool get isCancelled => this is AuthLoginModalCancelled;

  bool get isDismissed => this is AuthLoginModalDismissed;

  bool get isFailed => this is AuthLoginModalFailed;
}

final class AuthLoginModalSuccess extends AuthLoginModalResult {
  const AuthLoginModalSuccess({
    required this.provider,
    required this.user,
    this.accountLinked = true,
  });

  final AuthProviderType provider;
  final AuthUser user;
  final bool accountLinked;

  @override
  LoginModalResult toLoginModalResult() {
    return LoginModalResult.success(
      provider: provider.name,
      userId: user.userId,
      userNickname: user.nickname,
      accountLinked: accountLinked,
    );
  }
}

final class AuthLoginModalCancelled extends AuthLoginModalResult {
  const AuthLoginModalCancelled();

  @override
  LoginModalResult toLoginModalResult() => const LoginModalResult.cancelled();
}

final class AuthLoginModalDismissed extends AuthLoginModalResult {
  const AuthLoginModalDismissed();

  @override
  LoginModalResult toLoginModalResult() => const LoginModalResult.dismissed();
}

final class AuthLoginModalFailed extends AuthLoginModalResult {
  const AuthLoginModalFailed();

  @override
  LoginModalResult toLoginModalResult() => const LoginModalResult.failed();
}

/// 解析 [AppModalResult] 为 [AuthLoginModalResult]。
abstract final class AuthModalResults {
  static AuthLoginModalResult? asAuthLogin(AppModalResult result) {
    if (result is! LoginModalResult) {
      return null;
    }
    return AuthLoginModalResult.fromAppModalResult(result);
  }

  static bool isLoginSuccess(AppModalResult result) {
    return result is LoginModalResult && result.isSuccess;
  }
}
