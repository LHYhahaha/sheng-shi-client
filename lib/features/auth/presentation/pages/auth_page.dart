import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import '../../domain/auth_session.dart';
import '../widgets/auth_action_button.dart';

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
    final controller = ref.read(authControllerProvider.notifier);

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
              _LoginPanel(state: state, controller: controller),
          ],
        ),
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({required this.state, required this.controller});

  final AuthState state;
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 168,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.error != null) ...[
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
            AuthActionButton(
              label: l10n.authDeviceLogin,
              icon: Icons.phone_iphone_rounded,
              backgroundColor: const Color(0xFF262033),
              foregroundColor: AppColors.textPrimary,
              isLoading: state.pendingProvider == AuthProviderType.device,
              onPressed: state.pendingProvider == null
                  ? () => controller.login(AuthProviderType.device)
                  : null,
            ),
            const SizedBox(height: 12),
            AuthActionButton(
              label: l10n.authGoogleLogin,
              icon: Icons.g_mobiledata_rounded,
              backgroundColor: AppColors.textPrimary,
              foregroundColor: const Color(0xFF1A1A1A),
              isLoading: state.pendingProvider == AuthProviderType.google,
              onPressed: state.pendingProvider == null
                  ? () => controller.login(AuthProviderType.google)
                  : null,
            ),
            const SizedBox(height: 12),
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
                Positioned(
                  top: -12,
                  right: 0,
                  child: _ClaimBadge(label: l10n.authClaimCoins),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _TermsText(label: l10n.authTermsCopy),
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

class _TermsText extends StatelessWidget {
  const _TermsText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.5),
          height: 1.35,
        ),
      ),
    );
  }
}
