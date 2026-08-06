import '../../../core/analytics/analytics_popup_names.dart';
import '../domain/popup.dart';

/// 将运营弹窗配置转换为埋点表定义的展示参数。
Map<String, Object?>? popupShowParams(PopupConfig popup) {
  final targetType = popupTargetType(popup);
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

/// 运营弹窗内容点击的元素埋点参数。
///
/// 仅对 `/api/popup` 的有效运营配置生成参数；短剧配置必须带本次实际跳转的
/// 目标短剧及推荐方式，避免以弹窗配置或展示封面反推跳转目标。
Map<String, Object?>? campaignContentClickParams(PopupConfig popup) {
  final popupId = popup.id;
  final targetType = popupTargetType(popup);
  if (popupId == null || targetType == null) {
    return null;
  }

  final params = <String, Object?>{
    'element_name': 'campaign_content',
    'popup_config_id': '$popupId',
    'popup_target_type': targetType,
  };
  if (targetType != 'drama') {
    return params;
  }

  final dramaId = popup.shortDramaId;
  final recommendType = switch (popup.shortJumpMode) {
    1 => 'specified',
    2 => 'auto',
    _ => null,
  };
  if (dramaId == null || dramaId <= 0 || recommendType == null) {
    return null;
  }
  return {
    ...params,
    'target_drama_id': '$dramaId',
    'drama_recommend_type': recommendType,
  };
}

String? popupCloseName(PopupConfig popup) {
  return popupShowParams(popup) == null
      ? null
      : AnalyticsPopupNames.fixedCampaign;
}

String? popupTargetType(PopupConfig popup) {
  return switch (popup.jumpType) {
    1 => 'close',
    2 => 'h5',
    3 => 'drama',
    4 => 'page',
    _ => null,
  };
}
