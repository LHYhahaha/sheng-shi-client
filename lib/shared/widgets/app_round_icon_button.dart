import 'package:flutter/material.dart';

import 'app_tap_target.dart';

/// 圆形图标按钮的统一外观。
///
/// 点击热区交给 AppTapTarget 保证，视觉尺寸由 `size` 控制。不要在业务页复制圆形
/// Container + GestureDetector，否则无障碍标签和最小热区会很快不一致。
class AppRoundIconButton extends StatelessWidget {
  const AppRoundIconButton({
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 20,
    this.backgroundColor,
    this.iconColor = Colors.white,
    this.borderColor,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color iconColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}
