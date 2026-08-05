/// 某一时刻可自动补齐的公共埋点上下文。
///
/// 上下文在事件发生时被快照，不在异步上传时重新读取，避免离线事件被后续
/// 的登录态、页面或渠道状态污染。
class AnalyticsContext {
  const AnalyticsContext({
    required this.platform,
    required this.appVersion,
    required this.language,
    this.userId,
    this.channelId,
    this.merchantId,
    this.regionCode,
    this.pageName,
    this.previousPage,
    this.entrySourceType,
    this.entrySourceId,
    this.h5VisitorId,
  });

  final String platform;
  final String appVersion;
  final String language;
  final String? userId;
  final String? channelId;
  final String? merchantId;
  final String? regionCode;
  final String? pageName;
  final String? previousPage;
  final String? entrySourceType;
  final String? entrySourceId;
  final String? h5VisitorId;

  Map<String, Object?> toJson() {
    // 公共参数是后端固定 Schema：字段不可省略。当前上下文字段均为 string，
    // 缺失值以空字符串表示；后续若增加 number/bool/object/array 字段，也必须分别
    // 使用 0/false/{}/[] 作为默认值，不能删除 key。
    return <String, Object?>{
      'platform': platform,
      'app_version': appVersion,
      'language': language,
      'user_id': userId ?? '',
      'channel_id': channelId ?? '',
      'merchant_id': merchantId ?? '',
      'region_code': regionCode ?? '',
      'page_name': pageName ?? '',
      'previous_page': previousPage ?? '',
      'entry_source_type': entrySourceType ?? '',
      'entry_source_id': entrySourceId ?? '',
      'h5_visitor_id': h5VisitorId ?? '',
    };
  }
}

/// 单条事件的公共参数快照。
///
/// [eventId] 与 [eventTime] 在事件发生时生成。无论后续经过本地缓存、网络失败
/// 或重试，都必须复用该对象，不能生成新的值。
class AnalyticsCommonParams {
  const AnalyticsCommonParams({
    required this.eventId,
    required this.eventTime,
    required this.context,
  });

  final String eventId;
  final int eventTime;
  final AnalyticsContext context;

  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'event_time': eventTime,
    ...context.toJson(),
  };
}
