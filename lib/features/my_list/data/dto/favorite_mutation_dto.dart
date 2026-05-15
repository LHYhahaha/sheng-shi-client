/// 收藏/播放历史 mutation 响应 DTO。
///
/// 当前只保留 success 和 operationId，真实阶段可承接幂等结果、部分失败明细和服务端
/// 删除时间。UI 不应依赖这个 DTO。
class FavoriteMutationDto {
  const FavoriteMutationDto({required this.success, this.operationId});

  final bool success;
  final String? operationId;

  factory FavoriteMutationDto.fromJson(Object? data) {
    if (data is! Map<String, Object?>) {
      return const FavoriteMutationDto(success: true);
    }
    return FavoriteMutationDto(
      success: _boolValue(data['success']) ?? true,
      operationId: data['operationId'] is String
          ? data['operationId']! as String
          : null,
    );
  }
}

bool? _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => null,
    };
  }
  return null;
}
