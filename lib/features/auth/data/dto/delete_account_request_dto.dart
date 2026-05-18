/// 账号注销请求 DTO（remote contract；本轮 mock 可不发送全部字段）。
class DeleteAccountRequestDto {
  const DeleteAccountRequestDto({
    this.acceptedRisk,
    this.deviceId,
    this.sessionKind,
    this.reason,
  });

  /// 用户已在客户端勾选风险确认。
  final bool? acceptedRisk;

  /// 设备标识，供服务端风控与会话清理。
  final String? deviceId;

  /// `guest` / `authenticated`，用于区分游客与正式账号注销。
  final String? sessionKind;

  /// 可选备注或渠道来源。
  final String? reason;

  Map<String, Object?> toJson() => {
    if (acceptedRisk != null) 'acceptedRisk': acceptedRisk,
    if (deviceId != null) 'deviceId': deviceId,
    if (sessionKind != null) 'sessionKind': sessionKind,
    if (reason != null) 'reason': reason,
  };
}
