/// 广告解锁入口与弹窗共用的业务参数。
Map<String, Object?> adUnlockPopupAnalyticsParameters({
  required String dramaId,
  required String episodeId,
  required String dramaAccessType,
  required String adMaterialId,
}) {
  return {
    'drama_id': dramaId,
    'episode_id': episodeId,
    'drama_access_type': dramaAccessType,
    'ad_material_id': adMaterialId,
  };
}
