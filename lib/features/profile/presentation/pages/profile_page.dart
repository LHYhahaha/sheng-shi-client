import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/profile_controller.dart';
import '../widgets/profile_coins_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_membership_card.dart';
import '../widgets/profile_menu_row.dart';

/// 我的页。
///
/// 页面展示态由 Profile mock 数据和 AuthState 合成：会员/金币等资料仍来自
/// ProfileController，登录身份、昵称和头像以 AuthState 为准。这样 logout/delete
/// 后不需要手动同步 ProfileController，也避免多个页面各自维护登录布尔值。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profileState = ref.watch(profileControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final authUser = authState.user;
    // 这里只做展示层合成，不写回 profileState。Auth 是登录态源头；Profile 是资料
    // mock 源头。把合成结果回写会让退出登录后的旧昵称/头像残留在资料状态里。
    final state = profileState.copyWith(
      isLoggedIn: authState.isLoggedIn,
      userId: authUser?.id ?? profileState.userId,
      nickname: authUser?.nickname,
      avatarAssetPath:
          authUser?.avatarAssetPath ?? profileState.avatarAssetPath,
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          children: [
            ProfileHeader(
              state: state,
              onLoginTap: () => context.push(RoutePaths.auth),
              onAccountTap: () => context.push(RoutePaths.account),
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
              onTap: () => context.push(RoutePaths.settings),
            ),
          ],
        ),
      ),
    );
  }
}
