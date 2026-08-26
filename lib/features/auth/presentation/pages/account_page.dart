import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_session.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final user = state.user;
    final isBusy = state.isLoading;
    final errorLabel = _accountErrorLabel(context, state.failedAction);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      body: SafeArea(
        child: Column(
          children: [
            _AccountHeader(title: context.l10n.authAccountTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 32),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: AssetImage(
                            user?.avatarAssetPath ?? authDefaultAvatarAssetPath,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user?.nickname ?? context.l10n.profileGuest,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID:${user?.showId ?? '--'}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (state.error != null) ...[
                    Text(
                      errorLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _AccountActionRow(
                    label: context.l10n.authDeleteAccount,
                    destructive: true,
                    enabled: !isBusy,
                    onTap: () => context.push(RoutePaths.accountCancellation),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _accountErrorLabel(BuildContext context, AuthFailureAction? action) {
    final l10n = context.l10n;
    return switch (action) {
      AuthFailureAction.logout => l10n.authLogoutFailed,
      AuthFailureAction.deleteAccount => l10n.authDeleteAccountFailed,
      _ => l10n.authLoadFailed,
    };
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppSecondaryPageHeader(
      title: title,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.profile);
        }
      },
    );
  }
}

class _AccountActionRow extends StatelessWidget {
  const _AccountActionRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF17101F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: destructive
                      ? const Color(0xFFFF5A7A)
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
