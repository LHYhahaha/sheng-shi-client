import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次性附着到导流目标页首条 page_view 的来源信息。
class AnalyticsEntrySource {
  const AnalyticsEntrySource({required this.type, this.id = ''});

  final String type;
  final String id;
}

/// 保存一次待消费的配置型导流来源。
///
/// 只能由页面追踪器在 page_view 构建时消费；不会泄漏到后续事件。
class AnalyticsEntrySourceController extends Notifier<AnalyticsEntrySource?> {
  static const supportedTypes = <String>{
    'popup',
    'push',
    'banner',
    'share_deeplink',
  };

  @override
  AnalyticsEntrySource? build() => null;

  bool get hasPending => state != null;

  void prepare({required String type, String? id}) {
    if (!supportedTypes.contains(type)) {
      debugPrint('[Analytics] Unsupported entry source type: $type');
      return;
    }
    state = AnalyticsEntrySource(type: type, id: id?.trim() ?? '');
  }

  /// 读取并清空，保证只被目标页第一条 page_view 使用一次。
  AnalyticsEntrySource? consume() {
    final source = state;
    state = null;
    return source;
  }

  void clear() => state = null;
}

final analyticsEntrySourceProvider =
    NotifierProvider<AnalyticsEntrySourceController, AnalyticsEntrySource?>(
      AnalyticsEntrySourceController.new,
    );
