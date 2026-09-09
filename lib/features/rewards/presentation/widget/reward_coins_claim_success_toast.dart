import 'package:bot_toast/bot_toast.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

void showRewardCoinsClaimSuccessToast(BuildContext context, int rewardAmount) {
  final message = '+${context.l10n.rewardsClaimSuccessCoins(rewardAmount)}';
  BotToast.showCustomText(
    duration: const Duration(seconds: 2),
    onlyOne: true,
    align: Alignment.center,
    toastBuilder: (_) => Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('app_center_toast'),
        constraints: const BoxConstraints(minWidth: 122, maxWidth: 240),
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF363639),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/rewards/coins_reward_pop_icon.png',
              key: const Key('rewards_coins_claim_success_icon'),
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            // const SizedBox(height: 8),
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
