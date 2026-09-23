import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 应用主按钮。
///
/// 用于主要行动按钮，保持 FilledButton 行为一致。禁用态通过 `onPressed == null` 表达。
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调。
  ///
  /// null 表示禁用，调用方不要额外包 GestureDetector 绕过禁用态。
  final VoidCallback? onPressed;

  /// 可选前置图标。
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 14.sp,
      height: 18 / 14,
      fontWeight: FontWeight(590),
    );
    final child = icon == null
        ? Text(label, style: labelStyle)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              icon == Icons.play_arrow_rounded
                  ? Image.asset(
                      "assets/images/player/play_button_icon.png",
                      height: 12.w,
                      width: 12.w,
                    )
                  : Icon(icon, size: 18.w),
              SizedBox(width: 4.w),
              Text(label, style: labelStyle),
            ],
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 13.w),
          // backgroundColor: AppColors.primary,
          // foregroundColor: AppColors.textPrimary,
          // disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          // textStyle: const TextStyle(
          //   fontSize: 14,
          //   fontWeight: FontWeight.w700,
          //   height: 18 / 14,
          // ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
