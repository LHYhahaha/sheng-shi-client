import '../../../core/analytics/analytics_popup_names.dart';
import '../domain/popup.dart';

/// 将运营弹窗配置转换为埋点表定义的展示参数。
Map<String, Object?>? popupShowParams(PopupConfig popup) {
  final targetType = _popupTargetType(popup);
  if (targetType == null ||
      (targetType == 'drama' && popup.shortDramaId == null)) {
    return null;
  }

  return {
    // `/api/popup` 仅用于首页和 For You 的固定运营弹框；接口 name 是配置名，
    // 不参与埋点字典匹配。
    'popup_name': AnalyticsPopupNames.fixedCampaign,
    'popup_target_type': targetType,
    if (popup.id != null) 'popup_config_id': '${popup.id}',
    if (targetType == 'drama' && popup.shortDramaId != null)
      'target_drama_id': '${popup.shortDramaId}',
  };
}

String? popupCloseName(PopupConfig popup) {
  return popupShowParams(popup) == null
      ? null
      : AnalyticsPopupNames.fixedCampaign;
}

String? _popupTargetType(PopupConfig popup) {
  return switch (popup.jumpType) {
    1 => 'close',
    2 => 'h5',
    3 => 'drama',
    4 => 'page',
    _ => null,
  };
}
