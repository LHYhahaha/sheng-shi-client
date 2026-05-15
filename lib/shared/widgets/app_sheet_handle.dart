import 'package:flutter/material.dart';

/// 底部弹层拖拽提示条。
///
/// 组件只表达“这里是 sheet 顶部”的视觉 affordance，不绑定拖拽手势；实际拖拽能力
/// 由 bottom sheet 容器决定，避免业务弹窗误以为 handle 本身负责交互。
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({
    this.width = 42,
    this.height = 4,
    this.color,
    super.key,
  });

  /// handle 宽度。
  final double width;

  /// handle 高度。
  final double height;

  /// handle 颜色。
  ///
  /// null 时使用统一半透明白色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
