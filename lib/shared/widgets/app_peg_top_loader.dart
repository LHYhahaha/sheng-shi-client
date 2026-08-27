import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three staggered instances of the supplied polygon image falling into view.
///
/// The image is deliberately used without a color filter, preserving its
/// original pink gradient. Provide an SVG instead if runtime theme colors are
/// required later.
class AppPegTopLoader extends StatefulWidget {
  const AppPegTopLoader({
    this.size = 36,
    this.duration = const Duration(milliseconds: 1000),
    this.isAnimating = true,
    this.semanticLabel = 'Loading',
    super.key,
  }) : assert(size > 0);

  final double size;
  final Duration duration;
  final bool isAnimating;
  final String semanticLabel;

  @override
  State<AppPegTopLoader> createState() => _AppPegTopLoaderState();
}

class _AppPegTopLoaderState extends State<AppPegTopLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AppPegTopLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration)
      _controller.duration = widget.duration;
    if (oldWidget.isAnimating != widget.isAnimating) _syncAnimation();
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
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: List.generate(
                  3,
                  (index) => _FallingPolygon(
                    progress: (_controller.value - index * .3 + 1) % 1,
                    index: index,
                    size: widget.size,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallingPolygon extends StatelessWidget {
  const _FallingPolygon({
    required this.progress,
    required this.index,
    required this.size,
  });

  final double progress;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final keyframe = _PolygonKeyframe.at(progress, index);
    return Opacity(
      opacity: keyframe.opacity,
      child: Transform.translate(
        offset: Offset(keyframe.x * size, keyframe.y * size),
        child: Transform.rotate(
          angle: keyframe.angle * math.pi / 180,
          child: Transform.scale(
            scale: keyframe.scale,
            child: Image.asset(
              'assets/images/common/polygon_2.png',
              width: size,
              height: size,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _PolygonKeyframe {
  const _PolygonKeyframe({
    required this.x,
    required this.y,
    required this.scale,
    required this.angle,
    required this.opacity,
  });

  factory _PolygonKeyframe.at(double progress, int index) {
    const stops = [0.0, .25, .5, .75, 1.0];
    const scales = [.5, .75, 1.0, .5, 0.0];
    const ys = [-2.0, -1.0, 0.0, .5, 1.0];
    final xStart = switch (index) {
      1 => -1.0,
      2 => 1.0,
      _ => 0.0,
    };
    final xEnd = switch (index) {
      1 => .25,
      2 => -.25,
      _ => 0.0,
    };
    final angleStart = switch (index) {
      1 => -10.0,
      2 => 10.0,
      _ => 0.0,
    };
    final segment = (progress * 4).floor().clamp(0, 3).toInt();
    final local =
        (progress - stops[segment]) / (stops[segment + 1] - stops[segment]);
    double between(List<double> values) =>
        values[segment] + (values[segment + 1] - values[segment]) * local;

    return _PolygonKeyframe(
      x: xStart + (xEnd - xStart) * progress,
      y: between(ys),
      scale: between(scales),
      angle: angleStart + (-angleStart - angleStart) * progress,
      opacity: progress < .25
          ? progress * 4
          : progress > .75
          ? (1 - progress) * 4
          : 1,
    );
  }

  final double x;
  final double y;
  final double scale;
  final double angle;
  final double opacity;
}
