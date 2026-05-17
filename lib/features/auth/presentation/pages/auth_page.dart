import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import '../modal/auth_login_intent.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_login_modal_content.dart';

/// 全屏登录路由页（深链 / 测试保留）；主入口已迁移至全局 Login modal。
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _returnedAfterLogin = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider.select((state) => state.isLoggedIn), (
      previous,
      next,
    ) {
      if (!next || _returnedAfterLogin) {
        return;
      }
      _returnedAfterLogin = true;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RoutePaths.profile);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 6,
              child: IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go(RoutePaths.profile);
                },
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
            ),
            if (state.isLoading && !state.isLoggedIn)
              const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            else if (state.isLoggedIn)
              _LoggedInPanel(state: state)
            else
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.viewPaddingOf(context).bottom + 168,
                  ),
                  child: const AuthLoginModalContent(
                    intent: AuthLoginIntent.userInitiated,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoggedInPanel extends StatelessWidget {
  const _LoggedInPanel({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user != null)
              CircleAvatar(
                radius: 36,
                backgroundImage: AssetImage(user.avatarAssetPath),
              ),
            const SizedBox(height: 14),
            Text(
              user?.nickname ?? context.l10n.profileGuest,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID:${user?.id ?? '--'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            AuthActionButton(
              label: context.l10n.authAccountActions,
              icon: Icons.manage_accounts_rounded,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              onPressed: () => context.push(RoutePaths.account),
            ),
          ],
        ),
      ),
    );
  }
}
