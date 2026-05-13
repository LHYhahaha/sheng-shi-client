import 'package:flutter/material.dart';

class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({
    this.width = 42,
    this.height = 4,
    this.color,
    super.key,
  });

  final double width;
  final double height;
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
