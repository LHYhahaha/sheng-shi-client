import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../app/router/route_paths.dart';
import '../../application/auth_controller.dart';
import '../../application/phone_login_config_provider.dart';
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
    final isPhoneLoginEnabled = ref
        .watch(phoneLoginEnabledProvider)
        .when(
          data: (enabled) => enabled,
          loading: () => true,
          error: (_, _) => false,
        );

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
              fontSize: 12.sp,
              height: 1.35,
            ),
          ),
          SizedBox(height: 14.w),
        ],
        if (state.error != null &&
            (state.failedAction == AuthFailureAction.login ||
                state.failedAction == AuthFailureAction.load)) ...[
          Text(
            l10n.authLoadFailed,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontSize: 12.sp,
              height: 1.35,
            ),
          ),
          SizedBox(height: 14.w),
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
        AuthActionButton(
          label: l10n.authGoogleLogin,
          icon: Icons.g_mobiledata_rounded,
          assetIconPath: 'assets/images/auth/google_login.png',
          backgroundColor: AppColors.textPrimary,
          foregroundColor: const Color(0xFF1A1A1A),
          isLoading: state.pendingProvider == AuthProviderType.google,
          onPressed: state.pendingProvider == null
              ? () => controller.login(AuthProviderType.google)
              : null,
        ),
        SizedBox(height: 12.w),
        if (isPhoneLoginEnabled) ...[
          AuthActionButton(
            key: const ValueKey('auth_modal_phone_button'),
            label: l10n.authPhoneLogin,
            icon: Icons.phone_iphone_rounded,
            assetIconPath: 'assets/images/auth/mobile.png',
            backgroundColor: AppColors.textPrimary,
            foregroundColor: const Color(0xFF1A1A1A),
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(RoutePaths.phoneLogin);
            },
          ),
          SizedBox(height: 12.w),
        ],
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
        SizedBox(height: 18.w),
        const AuthTermsText(),
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
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 2.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/profile/coin.png',
              width: 14.w,
              height: 14.w,
            ),
            SizedBox(width: 3.w),
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

class AuthTermsText extends StatefulWidget {
  const AuthTermsText({this.width = 268, super.key});

  final double? width;

  @override
  State<AuthTermsText> createState() => _AuthTermsTextState();
}

class _AuthTermsTextState extends State<AuthTermsText> {
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.push(RoutePaths.userAgreement);
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.push(RoutePaths.privacyPolicy);
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
    final baseStyle = TextStyle(
      fontSize: 12.sp,
      color: Colors.white.withValues(alpha: 0.7),
      height: 1.5,
    );

    return SizedBox(
      width: widget.width?.w,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(
              text: l10n.loginAgreementPrefix,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            TextSpan(
              text: l10n.appCommonLegalTermsOfUse,
              style: TextStyle(color: linkColor),
              recognizer: _termsRecognizer,
            ),
            TextSpan(
              text: l10n.loginAgreementConnector,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
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
