import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../application/profile_controller.dart';

class ProfileCoinsCard extends StatelessWidget {
  const ProfileCoinsCard({
    required this.coins,
    required this.onTopUpTap,
    required this.onWalletTap,
    super.key,
  });

  final ProfileCoinsState coins;
  final VoidCallback onTopUpTap;
  final VoidCallback onWalletTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Color(0XFFFFFFFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: Color(0XFF312838), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.profileCoins,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('profile_wallet_entry'),
                behavior: HitTestBehavior.opaque,
                onTap: coins.walletEnabled ? onWalletTap : null,
                child: Row(
                  children: [
                    Text(
                      l10n.profileWallet,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    SizedBox(width: 3),
                    Image.asset(
                      "assets/images/profile/log_icon.png",
                      height: 15,
                      width: 15,
                    )
                  ],
                ),
              ),
            ],
          ),
          Divider(
            color: Color(0XFFFFFFFF).withValues(alpha: 0.06),
            height: 28,
          ),

          Row(
            children: [
              Image.asset(
                'assets/images/profile/coin.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${coins.balance}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('profile_top_up_entry'),
                behavior: HitTestBehavior.opaque,
                onTap: coins.topUpEnabled ? onTopUpTap : null,
                child: Container(
                  width: 73,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.profileTopUp,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight(510),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
