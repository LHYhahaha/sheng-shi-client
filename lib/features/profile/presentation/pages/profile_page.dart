import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../core/auth/user_info_store.dart';
import '../../../../core/network/test_network_config.dart';
import '../../../../core/network/test_network_config_dialog.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/media/media_resource.dart';
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
    final userInfoState = ref.watch(userInfoStoreProvider);
    final authUser = authState.user;

    // 监听 Tab 索引变化，每次切换到 Profile Tab 时刷新权益数据
    ref.listen(appShellCurrentTabIndexProvider, (previous, current) {
      if (current == AppShellDestinations.profileIndex && previous != current) {
        _loadEntitlementData();
      }
    });

    // 展示层合成：用户资料来自当前 token 同步后的 UserInfoStore；
    // 是否游客用于交互分流，以 AuthState 为准。
    // 金币数据来自 entitlementState（/api/user/entitlements 接口）
    final totalCoins =
        entitlementState.coinBalance + entitlementState.bonusBalance;
    final hasLinkedAccount = !authState.session.isGuest;

    // 优先使用 authUser 的 avatarResource，否则使用 userInfoState.avatar 构建网络头像
    final avatarResource =
        authUser?.avatarResource ??
        (userInfoState.avatar != null && userInfoState.avatar!.isNotEmpty
            ? MediaResource.network(userInfoState.avatar!)
            : profileState.avatarResource);

    final state = profileState.copyWith(
      isLoggedIn: hasLinkedAccount,
      userId: authUser?.id ?? userInfoState.showId,
      showId: authUser?.showId ?? userInfoState.showId,
      nickname: authUser?.nickname ?? userInfoState.nickname,
      avatarAssetPath:
          authUser?.avatarAssetPath ?? profileState.avatarAssetPath,
      avatarResource: avatarResource,
      membership: ProfileMembershipState(
        isActive: entitlementState.isMember,
        entryEnabled: profileState.membership.entryEnabled,
        expiresAt: entitlementState.membershipExpiresAt,
      ),
      coin: totalCoins,
    );

    void onHeaderTap() {
      if (authState.session.isGuest) {
        context.push(RoutePaths.auth);
      } else {
        // context.push(RoutePaths.account);
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
                if (authState.session.isGuest) {
                  context.push(RoutePaths.auth);
                }
              },
              onAccountTap: () => context.push(RoutePaths.account),
              onGuestTap: onHeaderTap,
            ),
            const SizedBox(height: 21),
            ProfileMembershipCard(
              membership: state.membership,
              onTap: () => context.push(
                RoutePaths.membershipLocation(returnToProfile: true),
              ),
            ),
            const SizedBox(height: 12),
            ProfileCoinsCard(
              coins: state.coins,
              onTopUpTap: () => context.push(RoutePaths.store),
              onWalletTap: () => context.push(RoutePaths.wallet),
            ),
            const SizedBox(height: 12),
            // ProfileMenuRow(
            //   title: l10n.profileHistory,
            //   iconAssetPath: 'assets/images/profile/history.png',
            //   onTap: () {},
            // ),
            ProfileMenuRow(
              title: l10n.profileLanguage,
              enabled: state.canOpenLanguage,
              onTap: () => context.push(RoutePaths.language),
            ),
            ProfileMenuRow(
              title: l10n.profileReward,
              iconAssetPath: 'assets/images/profile/reward.png',
              onTap: () => context.push(RoutePaths.rewardsLocation()),
            ),
            ProfileMenuRow(
              title: l10n.profileSettings,
              iconAssetPath: 'assets/images/profile/setting.png',
              onTap: () => context.push(RoutePaths.settings),
            ),
            if (TestNetworkTools.enabled)
              ProfileMenuRow(
                title: '测试网络配置 / 清理代理',
                onTap: () => showTestNetworkConfigDialog(context, ref),
              ),

            ProfileMenuRow(
              title: l10n.profileFeedback,
              iconAssetPath: 'assets/images/profile/feedback.png',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
