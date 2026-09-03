import 'dart:async';

import 'package:flutter/foundation.dart';
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
    this.cardScene,
    this.searchKeyword,
    this.visibilityRevision,
    this.isScrollInProgress,
    required this.child,
    super.key,
  });

  final Object pageSession;
  final AnalyticsService analytics;
  final String dramaId;
  final int position;
  final String? categoryId;
  final String? cardScene;
  final String? searchKeyword;

  /// 页面级可见性刷新信号。
  ///
  /// 传入后由页面在滚动停止时统一刷新，避免每张缓存中的卡片各自轮询。
  /// 未传入时保留通用组件原有的行为。
  final ValueListenable<int>? visibilityRevision;

  /// 页面滚动开始时立即撤销尚未满足停留时长的曝光计时。
  final ValueListenable<bool>? isScrollInProgress;
  final Widget child;

  /// 页面销毁时释放该会话的去重记录，避免静态缓存累积。
  static void releasePageSession(Object pageSession) {
    _DramaCardExposureState._reported.remove(pageSession);
  }

  @override
  State<DramaCardExposure> createState() => _DramaCardExposureState();
}

class _DramaCardExposureState extends State<DramaCardExposure> {
  static final _reported = <Object, Set<String>>{};
  Timer? _timer;
  Timer? _visibilityPoller;

  String get _dedupeKey {
    final categoryId = widget.categoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      return 'category:$categoryId:${widget.dramaId}';
    }
    final cardScene = widget.cardScene ?? '';
    final searchKeyword = cardScene == 'search_result'
        ? widget.searchKeyword ?? ''
        : '';
    return 'scene:$cardScene:$searchKeyword:${widget.dramaId}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
    final visibilityRevision = widget.visibilityRevision;
    if (visibilityRevision != null) {
      visibilityRevision.addListener(_evaluate);
    } else {
      _visibilityPoller = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _evaluate(),
      );
    }
    widget.isScrollInProgress?.addListener(_handleScrollActivityChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visibilityPoller?.cancel();
    widget.visibilityRevision?.removeListener(_evaluate);
    widget.isScrollInProgress?.removeListener(_handleScrollActivityChanged);
    super.dispose();
  }

  void _evaluate() {
    if (!mounted ||
        widget.isScrollInProgress?.value == true ||
        _isReported ||
        !_isAtLeastHalfVisible()) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(const Duration(seconds: 1), _report);
  }

  void _handleScrollActivityChanged() {
    if (widget.isScrollInProgress?.value == true) {
      _timer?.cancel();
      _timer = null;
    }
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
          ...?_optionalStringParameter('category_id', widget.categoryId),
          ...?_optionalStringParameter('card_scene', widget.cardScene),
          ...?_optionalStringParameter('search_keyword', widget.searchKeyword),
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visibilityRevision != null) return widget.child;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _evaluate();
        return false;
      },
      child: widget.child,
    );
  }
}

Map<String, Object?>? _optionalStringParameter(String key, String? value) {
  return value == null ? null : <String, Object?>{key: value};
}
