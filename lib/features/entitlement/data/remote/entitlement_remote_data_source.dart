import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/unlock_episode_request_dto.dart';
import '../dto/unlock_episode_response_dto.dart';
import '../dto/user_entitlement_state_dto.dart';

/// Entitlement 远程数据源骨架。
///
/// 权益状态、自动解锁设置和单集解锁都是登录后业务接口，统一使用 required。
class EntitlementRemoteDataSource {
  const EntitlementRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 获取权益状态（调用统一的权益接口）。
  ///
  /// 可选传入 [dramaId] 来获取该剧的已解锁剧集ID列表。
  /// 不传入时返回全局权益信息和未绑定剧集的解锁列表。
  Future<UserEntitlementStateDto> fetchEntitlements({int? dramaId}) async {
    final result = await fetchEntitlementsWithUserInfo(dramaId: dramaId);
    return result['dto'] as UserEntitlementStateDto;
  }

  /// 获取权益状态并返回用户信息。
  ///
  /// 返回包含 'dto' 和 'userInfo' 的 Map。
  Future<Map<String, dynamic>> fetchEntitlementsWithUserInfo({
    int? dramaId,
  }) async {
    final queryParams = dramaId != null ? {'dramaId': dramaId} : null;

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/user/entitlements',
      queryParameters: queryParams,
      authPolicy: ApiAuthPolicy.required,
      decoder: (json) => Map<String, dynamic>.from(json as Map),
    );

    final data = _entitlementData(response);
    final userInfo = _mapValue(data['userInfo']);
    final wallet = _mapValue(data['wallet']);
    final membership = _mapValue(data['membership']);
    final playback = _mapValue(data['playback']);
    final point = _mapValue(data['point']);

    // 转换解锁的剧集编号列表
    final unlockedEpisodeNos = playback['unlockedEpisodeNos'] as List?;
    final unlockedEpisodeIds = unlockedEpisodeNos != null
        ? unlockedEpisodeNos.map((e) => e.toString()).toList()
        : <String>[];

    final dto = UserEntitlementStateDto(
      isGuest: userInfo['isGuest'] as bool? ?? true,
      isMember: membership['isMember'] as bool? ?? false,
      membershipExpiresAt: membership['membershipExpiresAt'] != null
          ? JsonFieldParser.optionalDateTime(membership, 'membershipExpiresAt')
          : null,
      coinBalance: _intValue(wallet['coinBalance']),
      bonusBalance: _intValue(wallet['bonusBalance']),
      totalPointBalance: _intValue(point['totalPointBalance']),
      autoUnlockEnabled: playback['autoUnlockEnabled'] as bool? ?? false,
      unlockedEpisodeIds: unlockedEpisodeIds,
      pendingOperationId: playback['pendingOperationId'] as String?,
    );

    return {'dto': dto, 'userInfo': userInfo};
  }

  Future<UserEntitlementStateDto> setAutoUnlockEnabled(bool enabled) async {
    // 调用钱包接口设置自动解锁
    await _apiClient.post<Map<String, dynamic>>(
      '/api/user/auto-unlock/set',
      data: {'autoUnlock': enabled ? 1 : 0},
      authPolicy: ApiAuthPolicy.required,
      decoder: (json) => json as Map<String, dynamic>,
    );

    // 设置成功后，重新获取权益状态以同步最新的自动解锁状态
    return fetchEntitlements();
  }

  Future<UnlockEpisodeResponseDto> unlockEpisode(
    UnlockEpisodeRequestDto request,
  ) {
    return _apiClient.post<UnlockEpisodeResponseDto>(
      '/entitlements/unlock-episode',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: UnlockEpisodeResponseDto.fromJson,
    );
  }
}

Map<String, dynamic> _entitlementData(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return response;
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
