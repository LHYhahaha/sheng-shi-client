import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_session.dart';

/// 账号操作页。
///
/// logout/delete 的 loading 和错误留在 Account 侧展示，是为了让 Profile 继续只做
/// 登录态合成。真实账号系统接入后，破坏性动作仍应在这里确认和防重复点击，成功后
/// 再由 AuthState 统一回到 guest。
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
    final controller = ref.read(authControllerProvider.notifier);
    final user = state.user;
    // Account 页把 load/logout/delete 共用一个 busy 态，避免用户在退出或注销过程中
    // 继续触发另一个账号动作。错误文案则通过 failedAction 区分具体失败来源。
    final isBusy = state.isLoading;
    final errorLabel = _accountErrorLabel(context, state.failedAction);

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
                    label: context.l10n.authLogout,
                    isLoading: isBusy,
                    onTap: () async {
                      await controller.logout();
                      final nextState = ref.read(authControllerProvider);
                      if (context.mounted &&
                          nextState.error == null &&
                          !nextState.isLoggedIn) {
                        context.go(RoutePaths.profile);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  _AccountActionRow(
                    label: context.l10n.authDeleteAccount,
                    destructive: true,
                    enabled: !isBusy,
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

  String _accountErrorLabel(BuildContext context, AuthFailureAction? action) {
    final l10n = context.l10n;
    return switch (action) {
      AuthFailureAction.logout => l10n.authLogoutFailed,
      AuthFailureAction.deleteAccount => l10n.authDeleteAccountFailed,
      _ => l10n.authLoadFailed,
    };
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
    final nextState = ref.read(authControllerProvider);
    if (context.mounted && nextState.error == null && !nextState.isLoggedIn) {
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
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.profile);
                }
              },
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
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled && !isLoading ? onTap : null,
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
            if (isLoading)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
