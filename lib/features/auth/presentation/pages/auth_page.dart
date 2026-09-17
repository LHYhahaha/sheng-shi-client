import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/account/account_ban_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/oauth/oauth_service.dart';
import '../../../../core/oauth/oauth_service_provider.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';
import '../../application/auth_controller.dart';
import '../../application/facebook_login_config_provider.dart';
import '../../domain/auth_session.dart';
import '../widgets/auth_login_modal_content.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _returnedAfterLogin = false;
  bool _loginConfigRequested = false;
  bool _isAppleAuthorizing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loginConfigRequested) {
      return;
    }
    _loginConfigRequested = true;
    // 登录入口每次打开都必须重新读取服务端开关，不能复用上一次进入的缓存结果。
    ref.invalidate(loginConfigProvider);
  }

  void _returnToSourceAfterLogin(BuildContext context) {
    if (_returnedAfterLogin) {
      return;
    }
    _returnedAfterLogin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(RoutePaths.profile);
      }
    });
  }

  Future<void> _authorizeWithApple(BuildContext context) async {
    if (_isAppleAuthorizing) {
      return;
    }
    setState(() => _isAppleAuthorizing = true);
    try {
      final identityToken = await ref
          .read(facebookOAuthServiceProvider)
          .signInWithApple();
      if (!context.mounted) {
        return;
      }
      final toast = ref.read(appToastProvider);
      if (identityToken == null) {
        toast.info(context.l10n.authLoginCanceled);
      } else {
        // 后端 Apple 登录接口尚未接入；这里只确认原生授权能取得凭证。
        toast.info(context.l10n.authAppleAuthorizationSucceeded);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      debugPrint('[AuthPage] Apple authorization failed: $error');
      ref.read(appToastProvider).error(context.l10n.authLoginFailedRetryLater);
    } finally {
      if (mounted) {
        setState(() => _isAppleAuthorizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loginConfigState = ref.watch(loginConfigProvider);
    final loginConfig = loginConfigState.asData?.value;
    final isFacebookLoginEnabled = loginConfig?.facebookVisible ?? false;
    final isPhoneLoginEnabled = loginConfig?.phoneVisible ?? false;
    final isAppleSignInAvailable =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isGoogleSignInAvailable =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final l10n = context.l10n;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.isLoggedIn) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _returnToSourceAfterLogin(context);
        }
        return;
      }

      final loginJustFailed =
          previous?.failedAction != AuthFailureAction.login &&
          next.failedAction == AuthFailureAction.login &&
          next.error != null;
      if (!loginJustFailed) {
        return;
      }

      final toast = ref.read(appToastProvider);
      final error = next.error;
      if (error is OAuthLoginCancelledException) {
        toast.info(l10n.authLoginCanceled);
      } else if (error is ApiException &&
          error.businessCode == accountBannedBusinessCode) {
        toast.error(l10n.appAccountBannedDialogMessage);
      } else if (error is ApiException && error.canRetry) {
        toast.error(l10n.networkError);
      } else {
        toast.error(l10n.authLoginFailedRetryLater);
      }
    });

    if (state.isLoggedIn && (ModalRoute.of(context)?.isCurrent ?? false)) {
      _returnToSourceAfterLogin(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090012),
      // 手机号页在其上方显示键盘时，本页仍会留在 Navigator 栈内；不参与键盘
      // 尺寸压缩，保持登录方式页原始排版，也避免后台 route 的 RenderFlex 溢出。
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 2,
              child: AppSecondaryPageBackButton(
                key: const ValueKey('auth_back_button'),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop(false);
                    return;
                  }
                  context.go(RoutePaths.profile);
                },
              ),
            ),
            if (loginConfigState.isLoading)
              const Center(child: AppPegTopLoader())
            else if (!state.isLoggedIn && !_returnedAfterLogin)
              _LoginBody(
                pendingProvider: state.pendingProvider,
                onGooglePressed: state.pendingProvider == null
                    ? () => ref
                          .read(authControllerProvider.notifier)
                          .login(AuthProviderType.google)
                    : null,
                onFacebookPressed: state.pendingProvider == null
                    ? () => ref
                          .read(authControllerProvider.notifier)
                          .login(AuthProviderType.facebook)
                    : null,
                onApplePressed: _isAppleAuthorizing
                    ? null
                    : () => _authorizeWithApple(context),
                isFacebookLoginEnabled: isFacebookLoginEnabled,
                isPhoneLoginEnabled: isPhoneLoginEnabled,
                isAppleSignInAvailable: isAppleSignInAvailable,
                isGoogleSignInAvailable: isGoogleSignInAvailable,
                isAppleAuthorizing: _isAppleAuthorizing,
                onPhonePressed: () => context.push(RoutePaths.phoneLogin),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.pendingProvider,
    required this.onGooglePressed,
    required this.onFacebookPressed,
    required this.onApplePressed,
    required this.isFacebookLoginEnabled,
    required this.isPhoneLoginEnabled,
    required this.isAppleSignInAvailable,
    required this.isGoogleSignInAvailable,
    required this.isAppleAuthorizing,
    required this.onPhonePressed,
  });

  final AuthProviderType? pendingProvider;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;
  final VoidCallback? onApplePressed;
  final bool isFacebookLoginEnabled;
  final bool isPhoneLoginEnabled;
  final bool isAppleSignInAvailable;
  final bool isGoogleSignInAvailable;
  final bool isAppleAuthorizing;
  final VoidCallback onPhonePressed;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final l10n = context.l10n;
    final bottomInset = mediaQuery.viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset + 176),
      child: Column(
        children: [
          const Spacer(flex: 145),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/profile/logo.png',
              width: 62,
              height: 62,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            context.l10n.appTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const Spacer(flex: 181),
          if (isFacebookLoginEnabled) ...[
            _SocialLoginButton(
              key: const ValueKey('auth_facebook_button'),
              label: l10n.authFacebookLogin,
              isLoading: pendingProvider == AuthProviderType.facebook,
              onPressed: onFacebookPressed,
              backgroundColor: const Color(0xFF5981EF),
              foregroundColor: AppColors.textPrimary,
              icon: const Icon(Icons.facebook_rounded, size: 26),
            ),
            const SizedBox(height: 12),
          ],
          if (isGoogleSignInAvailable) ...[
            _SocialLoginButton(
              key: const ValueKey('auth_google_button'),
              label: l10n.authGoogleLogin,
              isLoading: pendingProvider == AuthProviderType.google,
              onPressed: onGooglePressed,
              backgroundColor: AppColors.textPrimary,
              foregroundColor: const Color(0xFF1A1A1A),
              icon: Image.asset(
                'assets/images/auth/google_login.png',
                width: 26,
                height: 26,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isAppleSignInAvailable) ...[
            _SocialLoginButton(
              key: const ValueKey('auth_apple_button'),
              label: l10n.loginButtonApple,
              isLoading: isAppleAuthorizing,
              onPressed: onApplePressed,
              backgroundColor: AppColors.textPrimary,
              foregroundColor: const Color(0xFF1A1A1A),
              icon: Image.asset(
                'assets/images/auth/apple.png',
                width: 25,
                height: 25,
              ),
            ),

            // SizedBox(
            //   key: const ValueKey('auth_apple_button'),
            //   width: double.infinity,
            //   child: SignInWithAppleButton(
            //     text: l10n.loginButtonApple,
            //     onPressed: onApplePressed,
            //   ),
            // ),
            const SizedBox(height: 12),
          ],
          if (isPhoneLoginEnabled) ...[
            _SocialLoginButton(
              key: const ValueKey('auth_phone_button'),
              label: l10n.authPhoneLogin,
              isLoading: false,
              onPressed: onPhonePressed,
              backgroundColor: AppColors.textPrimary,
              foregroundColor: const Color(0xFF1A1A1A),
              icon: Image.asset(
                'assets/images/auth/mobile.png',
                width: 30,
                height: 30,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const AuthTermsText(width: double.infinity),
        ],
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: key,
        onPressed: isLoading ? null : onPressed,
        icon: icon,
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 10),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.65),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
