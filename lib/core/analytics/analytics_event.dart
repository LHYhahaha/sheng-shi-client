/// 轻量埋点事件模型。
///
/// 当前只保留 name/properties，避免在业务层绑定具体分析 SDK。后续接 Firebase、
/// AppsFlyer 或自研埋点时，应在 adapter 层转换，不要让页面直接依赖 SDK 字段。
class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.parameters = const {}]);

  /// 事件名称。
  ///
  /// 应使用稳定枚举式命名，不要拼接动态 id，动态信息放入 parameters。
  final String name;

  /// 事件参数。
  ///
  /// 只放可序列化、非敏感值；不要放签名 URL、token 或原始异常对象。
  final Map<String, Object?> parameters;
}
