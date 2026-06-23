/// 账号注销响应 DTO（remote contract）。
class DeleteAccountResponseDto {
  const DeleteAccountResponseDto({
    required this.isCurrentDeviceAccount,
    required this.success,
  });

  /// 是否当前设备账号。
  ///
  /// - `true`：注销的是当前设备账号，需要清掉数据后直接退出App
  /// - `false`：注销的是三方登录账号，退出三方登录后返回me页面
  final bool isCurrentDeviceAccount;

  /// 注销是否成功。
  final bool success;

  factory DeleteAccountResponseDto.fromJson(Map<String, dynamic> json) {
    return DeleteAccountResponseDto(
      isCurrentDeviceAccount:
          json['isCurrentDeviceAccount'] as bool? ?? false,
      success: json['success'] as bool? ?? false,
    );
  }
}
