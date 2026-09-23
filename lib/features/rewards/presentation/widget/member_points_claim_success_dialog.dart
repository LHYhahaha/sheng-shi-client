import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';

import '../../../../l10n/app_localizations.dart';

const _memberPointsButtonColor = Color(0xFF8800FF);

Future<void> showMemberPointsClaimSuccessDialog(
  BuildContext context, {
  required int rewardAmount,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _MemberPointsClaimSuccessDialog(rewardAmount: rewardAmount);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _MemberPointsClaimSuccessDialog extends StatelessWidget {
  const _MemberPointsClaimSuccessDialog({required this.rewardAmount});

  final int rewardAmount;

  @override
  Widget build(BuildContext context) {
    final dialogWidth = (MediaQuery.sizeOf(context).width - 64.w).clamp(
      280.0.w,
      312.0.w,
    );
    final l10n = AppLocalizations.maybeOf(context);

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: dialogWidth,
            height: 350.w,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.w),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.0767],
                  colors: [Color(0xFF412061), Color(0xFF1C0C2C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF11001D).withValues(alpha: 0.8),
                    blurRadius: 28.w,
                    offset: Offset(0, 14.w),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14.w),
                      ),
                      child: Image.asset(
                        'assets/images/rewards/points_claime_pop_head_bac.png',
                        height: 48.w,
                        fit: BoxFit.fitHeight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12.w,
                    child: Text(
                      l10n.memberPointsSuccessTitle,
                      key: Key('member_points_claim_success_title'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 76.w,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Image.asset(
                          'assets/images/rewards/points_claime_pop_bac.png',
                          key: const Key('member_points_claim_success_image'),
                          width: 123.w,
                          height: 208.w,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                        ),
                        Positioned(
                          top: 103.w,
                          left: 15.w,
                          right: 15.w,
                          child: Center(
                            child: SizedBox(
                              width: 100.w,
                              height: 20.w,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  '+$rewardAmount',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Positioned(
                  //   top: 203,
                  //   child: Container(
                  //     key: const Key('member_points_claim_success_amount'),
                  //     width: 86,
                  //     height: 36,
                  //     alignment: Alignment.center,
                  //     decoration: BoxDecoration(
                  //       borderRadius: BorderRadius.circular(18),
                  //       gradient: const LinearGradient(
                  //         begin: Alignment.topCenter,
                  //         end: Alignment.bottomCenter,
                  //         colors: [Color(0xFF7E42C8), Color(0xFF5E229C)],
                  //       ),
                  //     ),
                  //     child: Text(
                  //       '+$rewardAmount',
                  //       style: const TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 24,
                  //         height: 1,
                  //         fontWeight: FontWeight.w800,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  Positioned(
                    left: 16.w,
                    right: 16.w,
                    bottom: 16.w,
                    child: _ClaimSuccessOkButton(
                      label: l10n.ok,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClaimSuccessOkButton extends StatelessWidget {
  const _ClaimSuccessOkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _memberPointsButtonColor,
          borderRadius: BorderRadius.circular(4.w),
          border: const GradientBoxBorder(
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
          ),
        ),
        child: CustomPaint(
          key: const Key('member_points_claim_success_ok_highlight'),
          foregroundPainter: const _ClaimSuccessButtonTopHighlightPainter(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('member_points_claim_success_ok'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(4.w),
              splashColor: Colors.white.withValues(alpha: 0.08),
              highlightColor: Colors.white.withValues(alpha: 0.04),
              child: SizedBox(
                height: 44.w,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClaimSuccessButtonTopHighlightPainter extends CustomPainter {
  const _ClaimSuccessButtonTopHighlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
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
  bool shouldRepaint(_ClaimSuccessButtonTopHighlightPainter oldDelegate) =>
      false;
}
