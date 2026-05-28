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

  /// 获取权益状态（调用钱包和会员状态接口）。
  Future<UserEntitlementStateDto> fetchEntitlements() async {
    // 并行调用两个接口获取最新的金币和会员状态
    final walletFuture = _apiClient.get<Map<String, dynamic>>(
      '/api/wallet',
      authPolicy: ApiAuthPolicy.required,
      decoder: (json) => json as Map<String, dynamic>,
    );
    
    final membershipFuture = _apiClient.get<Map<String, dynamic>>(
      '/api/payment/member/status',
      authPolicy: ApiAuthPolicy.required,
      decoder: (json) => json as Map<String, dynamic>,
    );

    final results = await Future.wait([walletFuture, membershipFuture]);
    final walletData = results[0] as Map<String, dynamic>;
    final membershipData = results[1] as Map<String, dynamic>;

    // 合并两个接口的数据
    return UserEntitlementStateDto(
      isGuest: false,
      isMember: membershipData['data']['isMember'] as bool? ?? false,
      membershipExpiresAt: membershipData['data']['vipExpireAt'] != null
          ? DateTime.tryParse(membershipData['data']['vipExpireAt'] as String)
          : null,
      coinBalance: walletData['data']['coin'] as int? ?? 0,
      bonusBalance: walletData['data']['bonusCoin'] as int? ?? 0,
      autoUnlockEnabled: false, // 从用户信息接口获取，这里暂时设为 false
      unlockedEpisodeIds: const [],
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
