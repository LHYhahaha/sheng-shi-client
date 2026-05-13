import 'package:flutter/material.dart';

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
