import 'package:flutter/material.dart';

/// 统一点击热区与语义标签的轻量包装。
///
/// 视觉图标可以小于 44px，但可点击区域默认不小于 44px，保证移动端易点和无障碍
/// 扫描稳定。新图标按钮优先复用这里，不要在业务组件里各自手写 GestureDetector。
class AppTapTarget extends StatelessWidget {
  const AppTapTarget({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.minSize = 44,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double minSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: Padding(
          padding: padding,
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );

    if (semanticLabel != null) {
      result = Semantics(
        button: true,
        enabled: onTap != null,
        label: semanticLabel,
        child: result,
      );
    }

    return result;
  }
}
