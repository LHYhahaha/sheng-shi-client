import '../../../../core/network/api_client.dart';
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

  Future<UserEntitlementStateDto> fetchEntitlements() {
    return _apiClient.get<UserEntitlementStateDto>(
      '/entitlements',
      authPolicy: ApiAuthPolicy.required,
      decoder: UserEntitlementStateDto.fromJson,
    );
  }

  Future<UserEntitlementStateDto> setAutoUnlockEnabled(bool enabled) {
    return _apiClient.patch<UserEntitlementStateDto>(
      '/entitlements/settings/auto-unlock',
      data: {'autoUnlockEnabled': enabled},
      authPolicy: ApiAuthPolicy.required,
      decoder: UserEntitlementStateDto.fromJson,
    );
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
