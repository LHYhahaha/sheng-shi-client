import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_modal_coordinator.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/profile_controller.dart';
import '../widgets/profile_coins_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_membership_card.dart';
import '../widgets/profile_menu_row.dart';

/// 我的页。
///
/// 金币数据来自 EntitlementController（/api/user/entitlements 接口），
/// 不再单独请求 /api/payment/wallet。
/// 登录身份、昵称和头像以 AuthState 为准。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    _loadEntitlementData();
  }

  void _loadEntitlementData() {
    Future.microtask(
      () => ref.read(entitlementControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profileState = ref.watch(profileControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final entitlementState = ref.watch(entitlementControllerProvider);
    final authModalCoordinator = ref.read(authModalCoordinatorProvider);
    final authUser = authState.user;

    // 监听 Tab 索引变化，每次切换到 Profile Tab 时刷新权益数据
    ref.listen(appShellCurrentTabIndexProvider, (previous, current) {
      if (current == AppShellDestinations.profileIndex && previous != current) {
        _loadEntitlementData();
      }
    });


    // 展示层合成：Auth 是登录态源头，Profile 是资料 mock 源头
    // 金币数据来自 entitlementState（/api/user/entitlements 接口）
    final totalCoins = entitlementState.coinBalance + entitlementState.bonusBalance;
    final state = profileState.copyWith(
      isLoggedIn: authState.isLoggedIn,
      userId: authUser?.id ?? profileState.userId,
      showId: authUser?.showId ?? profileState.showId,
      nickname: authUser?.nickname,
      avatarAssetPath: authUser?.avatarAssetPath ?? profileState.avatarAssetPath,
      coin: totalCoins,
    );

    void onHeaderTap() {
      if (entitlementState.isGuest) {
        authModalCoordinator.showLogin(context);
      } else {
        context.push(RoutePaths.account);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          children: [
            ProfileHeader(
              state: state,
              onLoginTap: () {
                if (entitlementState.isGuest) {
                  authModalCoordinator.showLogin(context);
                }
              },
              onAccountTap: () => context.push(RoutePaths.account),
              onGuestTap: onHeaderTap,
            ),
            const SizedBox(height: 21),
            ProfileMembershipCard(
              membership: state.membership,
              onTap: () => context.push(RoutePaths.membership),
            ),
            const SizedBox(height: 12),
            ProfileCoinsCard(
              coins: state.coins,
              onTopUpTap: () => context.push(RoutePaths.store),
              onWalletTap: () => context.push(RoutePaths.wallet),
            ),
            const SizedBox(height: 12),
            ProfileMenuRow(
              title: l10n.profileLanguage,
              enabled: state.canOpenLanguage,
              onTap: () => context.push(RoutePaths.language),
            ),
            ProfileMenuRow(
              title: l10n.profileSettings,
              iconAssetPath: 'assets/images/profile/setting.png',
              onTap: () => context.push(RoutePaths.settings),
            ),
          ],
        ),
      ),
    );
  }
}
