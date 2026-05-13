import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/auth_controller.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final user = state.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      body: SafeArea(
        bottom: false,
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
                            user?.avatarAssetPath ??
                                'assets/images/profile/profile_avatar_figma.png',
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
                          'ID:${user?.id ?? '--'}',
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
                  _AccountActionRow(
                    label: context.l10n.authLogout,
                    onTap: () async {
                      await controller.logout();
                      if (context.mounted) {
                        context.go(RoutePaths.profile);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  _AccountActionRow(
                    label: context.l10n.authDeleteAccount,
                    destructive: true,
                    onTap: () => _showDeleteAccountDialog(context, controller),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    AuthController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1728),
          title: Text(
            l10n.authDeleteAccount,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            l10n.authDeleteAccountMessage,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.storeCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.authDeleteAccountConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await controller.deleteAccount();
    if (context.mounted) {
      context.go(RoutePaths.profile);
    }
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: context.pop,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              color: AppColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

class _AccountActionRow extends StatelessWidget {
  const _AccountActionRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}
