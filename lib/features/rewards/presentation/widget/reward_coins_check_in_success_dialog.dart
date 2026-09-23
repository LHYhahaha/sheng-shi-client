import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

const _goldButtonBorder = GradientBoxBorder(
  width: 1,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.fromRGBO(255, 255, 255, 0.52),
      Color.fromRGBO(255, 255, 255, 0.10),
      Color.fromRGBO(255, 255, 255, 0.04),
      Color.fromRGBO(255, 255, 255, 0.08),
    ],
    stops: [0, 0.2767, 0.8906, 1],
  ),
);

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
    final width = (MediaQuery.sizeOf(context).width - 64.w).clamp(
      280.0.w,
      312.0.w,
    );
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: 240.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.w),
              border: GradientBoxBorder(
                width: 1,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFC895).withValues(alpha: 0.8),
                    Color(0xFFFFC895).withValues(alpha: 0),
                    Color(0xFFFFC895).withValues(alpha: 0),
                    Color(0xFFFFC895).withValues(alpha: 0),
                    Color(0xFFFFC895).withValues(alpha: 0),
                    Color(0xFFFFC895).withValues(alpha: 0),
                    Color(0xFFFFC895).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
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
                  top: -65.w,
                  child: Image.asset(
                    'assets/images/rewards/coins_pop_icon.png',
                    width: 128.w,
                    height: 128.w,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 65.w,
                  child: Text(
                    context.l10n.rewardsSigninSuccessTitle,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
                Positioned(
                  top: 105.w,
                  child: Text(
                    "+${context.l10n.rewardsSigninSuccessCoins(rewardAmount)}",
                    key: const Key('rewards_coins_claim_success_amount'),
                    style: TextStyle(
                      color: Color(0xFFFFD9B4),
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  left: 16.w,
                  right: 16.w,
                  bottom: 18.w,
                  child: GestureDetector(
                    key: const Key('rewards_coins_claim_success_ok'),
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      height: 44.w,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.w),
                          border: _goldButtonBorder,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD48851), Color(0xFFFFF3C7)],
                          ),
                        ),
                        child: CustomPaint(
                          foregroundPainter: const _ButtonTopHighlightPainter(),
                          child: Material(
                            color: Colors.transparent,
                            child: Center(
                              child: Text(
                                context.l10n.rewardsSigninSuccessConfirm,
                                style: TextStyle(
                                  color: Color(0xFF743000),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
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

class _ButtonTopHighlightPainter extends CustomPainter {
  const _ButtonTopHighlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.6),
          Colors.transparent,
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Offset.zero & size);
    canvas.drawLine(const Offset(4, 0.5), Offset(size.width - 4, 0.5), paint);
  }

  @override
  bool shouldRepaint(_ButtonTopHighlightPainter oldDelegate) => false;
}
