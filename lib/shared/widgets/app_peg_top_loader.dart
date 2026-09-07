import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shared animated line-chart loading indicator.
///
/// The name is retained so existing loading call sites continue to use the
/// same component. Its visual is a pink line chart: a muted track with a
/// moving, highlighted segment.
class AppPegTopLoader extends StatefulWidget {
  const AppPegTopLoader({
    this.size = 20,
    this.duration = const Duration(milliseconds: 1400),
    this.pauseDuration = const Duration(milliseconds: 500),
    this.isAnimating = true,
    this.noBackground = false,
    this.semanticLabel,
    super.key,
  }) : assert(size > 0);

  final double size;

  /// Time for one moving highlight to travel across the chart.
  final Duration duration;

  /// Delay after the highlight fades out before the next pass begins.
  final Duration pauseDuration;
  final bool isAnimating;

  /// Optional override for assistive technologies. Defaults to the localized
  /// common loading label from [AppLocalizations].
  final String? semanticLabel;

  /// Removes the dark rounded surface while retaining the line animation.
  final bool noBackground;

  @override
  State<AppPegTopLoader> createState() => _AppPegTopLoaderState();
}

class _AppPegTopLoaderState extends State<AppPegTopLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycleDuration,
  );

  Duration get _cycleDuration => widget.duration + widget.pauseDuration;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AppPegTopLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.pauseDuration != widget.pauseDuration) {
      _controller.duration = _cycleDuration;
    }
    if (oldWidget.isAnimating != widget.isAnimating) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isAnimating) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The chart is intentionally compact within its square background, with
    // room around the peak and trough like the reference loading mark.
    final lineSize = Size(widget.size * 2, widget.size * 1.55);
    final loader = Semantics(
      label: widget.semanticLabel ?? AppLocalizations.maybeOf(context).loading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: lineSize,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final motionFraction =
                    widget.duration.inMicroseconds /
                    _cycleDuration.inMicroseconds;
                return CustomPaint(
                  painter: _LineChartLoaderPainter(
                    // Hold at 1 during the pause; the painter makes the moving
                    // segment fully transparent at that point.
                    progress: (_controller.value / motionFraction)
                        .clamp(0, 1)
                        .toDouble(),
                    strokeWidth: widget.size * .11,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    return widget.noBackground
        ? loader
        : SizedBox.square(
            dimension: widget.size * 4.2,
            child: AppPegTopLoaderBackground(child: Center(child: loader)),
          );
  }
}

/// Reusable rounded dark surface for the shared loading animation.
class AppPegTopLoaderBackground extends StatelessWidget {
  const AppPegTopLoaderBackground({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color = const Color(0xE60A0014),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: color, borderRadius: borderRadius),
    child: child,
  );
}

class _LineChartLoaderPainter extends CustomPainter {
  const _LineChartLoaderPainter({
    required this.progress,
    required this.strokeWidth,
  });

  static const _color = Color(0xFFFF007A);

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .5)
      ..lineTo(size.width * .25, size.height * .5)
      ..lineTo(size.width * .32, size.height * .98)
      ..lineTo(size.width * .68, size.height * .02)
      ..lineTo(size.width * .75, size.height * .5)
      ..lineTo(size.width, size.height * .5);
    final trackPaint = Paint()
      ..color = _color.withValues(alpha: .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, trackPaint);

    final metric = path.computeMetrics().single;
    final dashLength = metric.length * .25;
    const entryFraction = .25;
    final isEntering = progress < entryFraction;
    final travelProgress = isEntering
        ? 0.0
        : (progress - entryFraction) / (1 - entryFraction);
    final start = metric.length * travelProgress;
    final visibleLength = isEntering
        ? dashLength * (progress / entryFraction)
        : dashLength;
    // The highlight stays visible until it exits at the right edge. The pause
    // then holds progress at 1, where it is fully hidden before restarting.
    final activeOpacity = progress < 1 ? 1.0 : 0.0;
    final activePaint = Paint()
      ..color = _color.withValues(alpha: activeOpacity.clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawSegment(canvas, metric, start, visibleLength, activePaint);
  }

  void _drawSegment(
    Canvas canvas,
    PathMetric metric,
    double start,
    double length,
    Paint paint,
  ) {
    final end = (start + length).clamp(0, metric.length).toDouble();
    if (start < end) {
      canvas.drawPath(metric.extractPath(start, end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth;
}
