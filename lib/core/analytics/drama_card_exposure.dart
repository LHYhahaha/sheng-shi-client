import 'dart:async';

import 'package:flutter/material.dart';

import 'analytics_definition.dart';
import 'analytics_event.dart';
import 'analytics_service.dart';

/// 短剧卡片曝光：可视面积至少 50% 持续一秒后，仅在当前页面会话内上报一次。
class DramaCardExposure extends StatefulWidget {
  const DramaCardExposure({
    required this.pageSession,
    required this.analytics,
    required this.dramaId,
    required this.position,
    this.categoryId,
    required this.child,
    super.key,
  });

  final Object pageSession;
  final AnalyticsService analytics;
  final String dramaId;
  final int position;
  final String? categoryId;
  final Widget child;

  @override
  State<DramaCardExposure> createState() => _DramaCardExposureState();
}

class _DramaCardExposureState extends State<DramaCardExposure> {
  static final _reported = <Object, Set<String>>{};
  Timer? _timer;
  Timer? _visibilityPoller;

  String get _dedupeKey => '${widget.categoryId ?? ''}:${widget.dramaId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
    _visibilityPoller = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _evaluate(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visibilityPoller?.cancel();
    super.dispose();
  }

  void _evaluate() {
    if (!mounted || _isReported || !_isAtLeastHalfVisible()) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(const Duration(seconds: 1), _report);
  }

  bool get _isReported =>
      _reported[widget.pageSession]?.contains(_dedupeKey) ?? false;

  bool _isAtLeastHalfVisible() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final viewport = Offset.zero & MediaQuery.sizeOf(context);
    final visible = rect.intersect(viewport);
    if (visible.isEmpty || rect.isEmpty) return false;
    return visible.width * visible.height >= rect.width * rect.height * .5;
  }

  void _report() {
    _timer = null;
    if (!mounted || !_isAtLeastHalfVisible() || _isReported) return;
    (_reported[widget.pageSession] ??= <String>{}).add(_dedupeKey);
    unawaited(
      widget.analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.dramaCardExposure, {
          'drama_id': widget.dramaId,
          'position': widget.position,
          if (widget.categoryId != null) 'category_id': widget.categoryId!,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _evaluate();
          return false;
        },
        child: widget.child,
      );
}
