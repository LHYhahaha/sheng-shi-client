import 'package:bot_toast/bot_toast.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

void showRewardCoinsClaimSuccessToast(int rewardAmount) {
  BotToast.showCustomText(
    duration: const Duration(seconds: 2),
    onlyOne: true,
    align: Alignment.center,
    toastBuilder: (_) =>
        _RewardCoinsClaimSuccessToast(rewardAmount: rewardAmount),
  );
}

class _RewardCoinsClaimSuccessToast extends StatelessWidget {
  const _RewardCoinsClaimSuccessToast({required this.rewardAmount});

  final int rewardAmount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('rewards_coins_claim_success_toast'),
        height: 98,
        padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF3B3A40),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/rewards/coins_reward_pop_icon.png',
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 2),
            Text(
              "+${context.l10n.rewardsClaimSuccessCoins(rewardAmount)}",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
