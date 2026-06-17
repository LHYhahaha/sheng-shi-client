import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../app/router/route_paths.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_session.dart';
import '../modal/auth_login_intent.dart';
import 'auth_action_button.dart';

/// 登录弹窗/页面共用的 provider 按钮区（mock OAuth 入口）。
class AuthLoginModalContent extends ConsumerWidget {
  const AuthLoginModalContent({
    this.intent = AuthLoginIntent.userInitiated,
    this.reason,
    this.message,
    super.key,
  });

  final AuthLoginIntent intent;
  final AuthLoginRequiredReason? reason;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    final prompt = message ?? _defaultMessage(l10n);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prompt != null) ...[
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (state.error != null &&
            (state.failedAction == AuthFailureAction.login ||
                state.failedAction == AuthFailureAction.load)) ...[
          Text(
            l10n.authLoadFailed,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
        ],
        // TODO(暂未开放): Device登录按钮 - 2026-06-15
        // AuthActionButton(
        //   label: l10n.authDeviceLogin,
        //   icon: Icons.phone_iphone_rounded,
        //   backgroundColor: const Color(0xFF262033),
        //   foregroundColor: AppColors.textPrimary,
        //   isLoading: state.pendingProvider == AuthProviderType.device,
        //   onPressed: state.pendingProvider == null
        //       ? () => controller.login(AuthProviderType.device)
        //       : null,
        // ),
        // const SizedBox(height: 12),
        // TODO(暂未开放): Google登录按钮 - 2026-06-15
        // AuthActionButton(
        //   label: l10n.authGoogleLogin,
        //   icon: Icons.g_mobiledata_rounded,
        //   backgroundColor: AppColors.textPrimary,
        //   foregroundColor: const Color(0xFF1A1A1A),
        //   isLoading: state.pendingProvider == AuthProviderType.google,
        //   onPressed: state.pendingProvider == null
        //       ? () => controller.login(AuthProviderType.google)
        //       : null,
        // ),
        // const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            AuthActionButton(
              label: l10n.authFacebookLogin,
              icon: Icons.facebook_rounded,
              backgroundColor: const Color(0xFF5981EF),
              foregroundColor: AppColors.textPrimary,
              isLoading: state.pendingProvider == AuthProviderType.facebook,
              onPressed: state.pendingProvider == null
                  ? () => controller.login(AuthProviderType.facebook)
                  : null,
            ),
            // Positioned(
            //   top: -12,
            //   right: 0,
            //   child: _ClaimBadge(label: l10n.authClaimCoins),
            // ),
          ],
        ),
        const SizedBox(height: 18),
        const _TermsText(),
      ],
    );
  }

  String? _defaultMessage(AppLocalizations l10n) {
    return switch (intent) {
      AuthLoginIntent.userInitiated => null,
      AuthLoginIntent.loginRequired => l10n.authLoginRequiredMessage,
      AuthLoginIntent.sessionExpiredPrompt => l10n.authSessionExpiredMessage,
    };
  }
}

class _ClaimBadge extends StatelessWidget {
  const _ClaimBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/profile/coin.png',
              width: 14,
              height: 14,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsText extends StatefulWidget {
  const _TermsText();

  @override
  State<_TermsText> createState() => _TermsTextState();
}

class _TermsTextState extends State<_TermsText> {
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.go(RoutePaths.userAgreement);
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.go(RoutePaths.privacyPolicy);
      };
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final linkColor = Colors.white.withValues(alpha: 0.7);
    final baseStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.7),
      height: 1.35,
    );

    return SizedBox(
      width: 268,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: l10n.loginAgreementPrefix),
            TextSpan(
              text: l10n.appCommonLegalTermsOfUse,
              style: TextStyle(color: linkColor),
              recognizer: _termsRecognizer,
            ),
            TextSpan(text: l10n.loginAgreementConnector),
            TextSpan(
              text: l10n.appCommonLegalPrivacyPolicy,
              style: TextStyle(color: linkColor),
              recognizer: _privacyRecognizer,
            ),
            TextSpan(text: l10n.loginAgreementSuffix),
          ],
        ),
      ),
    );
  }
}
