import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(authControllerProvider.notifier);
    final authState = ref.watch(authControllerProvider);
    final isGuest = authState.session.isGuest;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsHeader(title: l10n.profileSettings),
            const SizedBox(height: 12),
            _SettingsRow(
              key: const ValueKey('settings_account_cancellation_row'),
              title: l10n.settingsDeleteAccount,
              onTap: () => context.push(RoutePaths.accountCancellation),
            ),
            _SettingsRow(
              key: const ValueKey('settings_user_agreement_row'),
              title: l10n.settingsUserAgreement,
              onTap: () => context.push(RoutePaths.userAgreement),
            ),
            _SettingsRow(
              key: const ValueKey('settings_privacy_policy_row'),
              title: l10n.settingsPrivacyPolicy,
              onTap: () => context.push(RoutePaths.privacyPolicy),
            ),
            if (!isGuest)
              InkWell(
                onTap: () async {
                  await controller.logout();
                  final nextState = ref.read(authControllerProvider);
                  if (context.mounted &&
                      nextState.error == null &&
                      nextState.session.isGuest) {
                    final message = context.l10n.authLogoutSuccess;
                    ref.read(appToastProvider).success(message);
                    context.go(RoutePaths.profile);
                  }
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  margin: const EdgeInsets.symmetric(horizontal: 50,vertical: 40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Color(0xFFFFFFFF).withValues(alpha: 0.1),
                  ),
                  child: Text(
                    context.l10n.settingsButtonLogout,
                    style: TextStyle(color: Color(0XFFFF007A), fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            child: IconButton(
              key: const ValueKey('settings_back_button'),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.profile);
                }
              },
              padding: EdgeInsets.zero,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 22 / 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.title, required this.onTap, super.key});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 16,
                    height: 22 / 16,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
