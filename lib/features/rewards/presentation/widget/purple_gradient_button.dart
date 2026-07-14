import 'package:flutter/material.dart';

class PurpleGradientButton extends StatelessWidget {
  const PurpleGradientButton({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.borderWidth = 1,
    this.backgroundColor = Colors.transparent,
    this.backgroundGradient,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;

  final double? width;
  final double? height;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  final double borderRadius;
  final double borderWidth;

  final Color backgroundColor;
  final Gradient? backgroundGradient;

  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow,
        ),
        child: CustomPaint(
          foregroundPainter: _GradientBorderPainter(
            borderRadius: borderRadius,
            borderWidth: borderWidth,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            clipBehavior: clipBehavior,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundGradient == null ? backgroundColor : null,
                gradient: backgroundGradient,
              ),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  const _GradientBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
  });

  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || borderWidth <= 0) return;

    final outerRect = Offset.zero & size;

    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      Radius.circular(borderRadius),
    );

    final innerRect = outerRect.deflate(borderWidth);

    final innerRadius =
    (borderRadius - borderWidth).clamp(0.0, double.infinity);

    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerRadius),
    );

    // 仅绘制边框区域
    final borderPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outerRRect),
      Path()..addRRect(innerRRect),
    );

    canvas.save();
    canvas.clipPath(borderPath);

    // 第一层：上下透明渐变
    const linearGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.fromRGBO(255, 255, 255, 0.52),
        Color.fromRGBO(255, 255, 255, 0.10),
        Color.fromRGBO(255, 255, 255, 0.04),
        Color.fromRGBO(255, 255, 255, 0.08),
      ],
      stops: [
        0.0,
        0.2767,
        0.8906,
        1.0,
      ],
    );

    canvas.drawRect(
      outerRect,
      Paint()..shader = linearGradient.createShader(outerRect),
    );

    // 第二层：顶部椭圆高光
    final center = Offset(size.width / 2, 0);

    final horizontalRadius = size.width * 0.2551;
    final verticalRadius = size.height * 0.1008;

    if (horizontalRadius > 0 && verticalRadius > 0) {
      canvas.save();

      canvas.translate(center.dx, center.dy);

      canvas.scale(
        1,
        verticalRadius / horizontalRadius,
      );

      canvas.translate(-center.dx, -center.dy);

      final radialRect = Rect.fromCircle(
        center: center,
        radius: horizontalRadius,
      );

      const radialGradient = RadialGradient(
        center: Alignment.topCenter,
        radius: 1,
        colors: [
          Colors.white,
          Colors.transparent,
        ],
      );

      canvas.drawRect(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height * horizontalRadius / verticalRadius,
        ),
        Paint()
          ..shader = radialGradient.createShader(radialRect)
          ..blendMode = BlendMode.screen,
      );

      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth;
  }
}