import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/oauth/oauth_service.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_session.dart';
import '../widgets/auth_login_modal_content.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _returnedAfterLogin = false;

  void _returnToSourceAfterLogin(BuildContext context) {
    if (_returnedAfterLogin) {
      return;
    }
    _returnedAfterLogin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(RoutePaths.profile);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final l10n = context.l10n;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.isLoggedIn) {
        _returnToSourceAfterLogin(context);
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
      } else if (error is ApiException && error.canRetry) {
        toast.error(l10n.networkError);
      } else {
        toast.error(l10n.authLoginFailedRetryLater);
      }
    });

    if (state.isLoggedIn) {
      _returnToSourceAfterLogin(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090012),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 2,
              child: IconButton(
                key: const ValueKey('auth_back_button'),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop(false);
                    return;
                  }
                  context.go(RoutePaths.profile);
                },
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
              ),
            ),
            if (!state.isLoggedIn && !_returnedAfterLogin)
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
  });

  final AuthProviderType? pendingProvider;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;

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
        icon: isLoading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : icon,
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 10),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.65),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
