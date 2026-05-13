import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/profile_controller.dart';
import '../widgets/profile_coins_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_membership_card.dart';
import '../widgets/profile_menu_row.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          children: [
            ProfileHeader(state: state),
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
          ],
        ),
      ),
    );
  }
}
