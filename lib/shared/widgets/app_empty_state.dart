import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.message,
    this.buttonLabel,
    this.onButtonPressed,
    this.assetPath = defaultAssetPath,
    this.imageSize = 120,
    this.spacing = 6,
    this.buttonTopSpacing = 20,
    this.buttonWidth = 228,
    this.padding = EdgeInsets.zero,
    this.textStyle,
    super.key,
  });

  static const defaultAssetPath = 'assets/images/home/empty_icon.svg';

  final String message;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final String assetPath;
  final double imageSize;
  final double spacing;
  final double buttonTopSpacing;
  final double buttonWidth;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle =
        textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary.withValues(alpha: 0.3),
          fontSize: 12.sp,
          height: 16 / 12,
        );
    final showButton = buttonLabel != null && onButtonPressed != null;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            assetPath,
            width: imageSize.w,
            height: imageSize.w,
            fit: BoxFit.contain,
          ),
          SizedBox(height: spacing.w),
          Text(message, textAlign: TextAlign.center, style: effectiveTextStyle),
          if (showButton) ...[
            SizedBox(height: buttonTopSpacing.w),
            SizedBox(
              width: buttonWidth.w,
              height: 32.w,
              child: FilledButton(
                onPressed: onButtonPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.w),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                  ),
                ),
                child: Text(buttonLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
