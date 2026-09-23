import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.assetIconPath,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final String? assetIconPath;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.w,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: assetIconPath == null
            ? Icon(icon, size: 22.w)
            : Image.asset(assetIconPath!, width: 22.w, height: 22.w),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.65),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.w),
          ),
          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
