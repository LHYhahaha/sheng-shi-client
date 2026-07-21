import 'package:flutter/material.dart';

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
      height: compact ? 32 : 34,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.65),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: Size(width ?? 96, compact ? 32 : 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 16 / 12,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
