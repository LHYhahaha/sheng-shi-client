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

  /// 图标。
  final IconData icon;

  /// 点击回调。
  ///
  /// null 表示禁用，点击热区仍保持稳定尺寸。
  final VoidCallback? onTap;

  /// 无障碍标签。
  ///
  /// 纯图标按钮应提供，避免读屏只读出“按钮”。
  final String? semanticLabel;

  /// 圆形视觉尺寸。
  ///
  /// 不等于最小点击热区；点击热区由 AppTapTarget 兜底。
  final double size;

  /// 图标尺寸。
  final double iconSize;

  /// 背景色。
  final Color? backgroundColor;

  /// 图标颜色。
  final Color iconColor;

  /// 边框色。
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
