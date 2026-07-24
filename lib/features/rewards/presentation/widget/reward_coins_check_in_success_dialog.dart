import 'package:flutter/material.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

Future<void> showRewardCoinsCheckInSuccessDialog(
  BuildContext context, {
  required int rewardAmount,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    pageBuilder: (_, _, _) =>
        _RewardCoinsCheckInSuccessDialog(rewardAmount: rewardAmount),
  );
}

class _RewardCoinsCheckInSuccessDialog extends StatelessWidget {
  const _RewardCoinsCheckInSuccessDialog({required this.rewardAmount});

  final int rewardAmount;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 64).clamp(280.0, 312.0);
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: const GradientBoxBorder(
                width: 1,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD392), Color(0xFF6C3B13)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              image: const DecorationImage(
                image: AssetImage('assets/images/rewards/coins_pop_bac.png'),
                fit: BoxFit.fill,
              ),
            ),
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -51,
                  child: Image.asset(
                    'assets/images/rewards/coins_reward_pop_icon.png',
                    width: 145,
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                ),
                const Positioned(
                  top: 65,
                  child: Text(
                    'Check-in successful',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Positioned(
                  top: 105,
                  child: Text(
                    '+$rewardAmount coins',
                    key: const Key('rewards_coins_claim_success_amount'),
                    style: const TextStyle(
                      color: Color(0xFFFFD9B4),
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SizedBox(
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD48851), Color(0xFFFFF3C7)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('rewards_coins_claim_success_ok'),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Center(
                            child: Text(
                              'Claim',
                              style: TextStyle(
                                color: Color(0xFF743000),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
