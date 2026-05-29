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
      '/api/payment/wallet',
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
      isMember: membershipData['isMember'] as bool? ?? false,
      membershipExpiresAt: membershipData['vipExpireAt'] != null
          ? DateTime.tryParse(membershipData['vipExpireAt'] as String)
          : null,
      coinBalance: int.parse(walletData['coin'])  as int? ?? 0,
      bonusBalance: int.parse(walletData['bonusCoin']) as int? ?? 0,
      autoUnlockEnabled: walletData['autoUnlockEnabled'] as bool? ?? false,
      unlockedEpisodeIds: const [],
    );
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
