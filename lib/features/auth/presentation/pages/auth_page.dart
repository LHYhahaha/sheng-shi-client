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
                isLoading: state.pendingProvider == AuthProviderType.facebook,
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
  const _LoginBody({required this.isLoading, required this.onFacebookPressed});

  final bool isLoading;
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
              child: Image.asset('assets/images/profile/logo.png', width: 62, height: 62)),
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
          _FacebookLoginButton(
            label: l10n.authFacebookLogin,
            isLoading: isLoading,
            onPressed: onFacebookPressed,
          ),
          const SizedBox(height: 12),
          const AuthTermsText(width: double.infinity),
        ],
      ),
    );
  }
}

class _FacebookLoginButton extends StatelessWidget {
  const _FacebookLoginButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('auth_facebook_button'),
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : const Icon(Icons.facebook_rounded, size: 26),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 10),
          backgroundColor: const Color(0xFF5981EF),
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: const Color(
            0xFF5981EF,
          ).withValues(alpha: 0.65),
          disabledForegroundColor: AppColors.textPrimary.withValues(
            alpha: 0.75,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
