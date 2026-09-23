import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// 普通二级页面统一使用的标题栏。
///
/// 沉浸式页面、搜索页和包含 Tab 的标题栏不使用此组件。
class AppSecondaryPageHeader extends StatelessWidget {
  const AppSecondaryPageHeader({
    required this.title,
    required this.onBack,
    this.backButtonKey,
    this.trailing,
    super.key,
  });

  static const height = 56.0;
  static const backButtonSize = 40.0;
  static const backIconSize = 20.0;
  static const horizontalInset = 6.0;
  static const actionSlotWidth = backButtonSize + horizontalInset * 2;

  final String title;
  final VoidCallback onBack;
  final Key? backButtonKey;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height.w,
      child: Row(
        children: [
          SizedBox(
            width: actionSlotWidth.w,
            child: Padding(
              padding: EdgeInsets.only(left: horizontalInset.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppSecondaryPageBackButton(
                  key: backButtonKey,
                  onPressed: onBack,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(
            width: actionSlotWidth.w,
            child: trailing == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(right: horizontalInset.w),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class AppSecondaryPageBackButton extends StatelessWidget {
  const AppSecondaryPageBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      constraints: BoxConstraints.tightFor(
        width: AppSecondaryPageHeader.backButtonSize.w,
        height: AppSecondaryPageHeader.backButtonSize.w,
      ),
      icon: Image.asset(
        'assets/images/common/come_back.png',
        width: AppSecondaryPageHeader.backIconSize.w,
        height: AppSecondaryPageHeader.backIconSize.w,
      ),
    );
  }
}
