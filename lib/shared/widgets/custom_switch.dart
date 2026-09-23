import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

class CustomSwitch extends StatelessWidget {
  const CustomSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 48.w,
        height: 28.w,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.white.withValues(alpha: 0.12)
              : value
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(999.w),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: disabled
                  ? AppColors.textPrimary.withValues(alpha: 0.5)
                  : AppColors.textPrimary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
