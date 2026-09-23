import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

class AppRetryButton extends StatelessWidget {
  const AppRetryButton({
    required this.onPressed,
    required this.label,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = compact ? null : screenWidth / 2;

    return SizedBox(
      width: width,
      height: compact ? 32.w : 34.w,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.65),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          minimumSize: Size(width ?? 96.w, compact ? 32.w : 34.w),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.w),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            height: 16 / 12,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
