import 'package:bot_toast/bot_toast.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum RewardClaimToastType { coins, points }

void showRewardCoinsClaimSuccessToast(BuildContext context, int rewardAmount) {
  showRewardClaimSuccessToast(
    context,
    rewardAmount: rewardAmount,
    type: RewardClaimToastType.coins,
  );
}

void showRewardClaimSuccessToast(
  BuildContext context, {
  required int rewardAmount,
  required RewardClaimToastType type,
}) {
  final isCoins = type == RewardClaimToastType.coins;
  final message = isCoins
      ? '+${context.l10n.rewardsClaimSuccessCoins(rewardAmount)}'
      : '+${context.l10n.rewardsClaimSuccessPoints(rewardAmount)}';
  BotToast.showCustomText(
    duration: const Duration(seconds: 2),
    onlyOne: true,
    align: Alignment.center,
    toastBuilder: (_) => Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('app_center_toast'),
        width: 122,
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF363639),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              isCoins
                  ? 'assets/images/rewards/coins_reward_pop_icon.png'
                  : 'assets/images/rewards/points_reward_icon.png',
              key: Key(
                isCoins
                    ? 'rewards_coins_claim_success_icon'
                    : 'rewards_points_claim_success_icon',
              ),
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
