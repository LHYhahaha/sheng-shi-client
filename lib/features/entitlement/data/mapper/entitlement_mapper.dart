import '../../../../core/network/api_mapping_exception.dart';
import '../../domain/episode_access_decision.dart';
import '../../domain/episode_unlock_type.dart';
import '../../domain/user_entitlement_state.dart';
import '../dto/episode_access_decision_dto.dart';
import '../dto/unlock_episode_response_dto.dart';
import '../dto/user_entitlement_state_dto.dart';

/// Entitlement 远程 DTO 到 domain 的 mapper。
class EntitlementMapper {
  const EntitlementMapper();

  UserEntitlementState mapState(UserEntitlementStateDto dto) {
    return UserEntitlementState(
      isGuest: dto.isGuest,
      isMember: dto.isMember,
      coinBalance: dto.coinBalance,
      bonusBalance: dto.bonusBalance,
      totalPointBalance: dto.totalPointBalance,
      membershipExpiresAt: dto.membershipExpiresAt,
      pendingOperationId: dto.pendingOperationId,
      serverTime: dto.serverTime,
      refreshReason: dto.refreshReason,
      autoUnlockEnabled: dto.autoUnlockEnabled,
      unlockedEpisodeIds: dto.unlockedEpisodeIds.toSet(),
    );
  }

  EpisodeAccessDecision mapDecision(EpisodeAccessDecisionDto dto) {
    return EpisodeAccessDecision(
      type: _decisionType(dto.type),
      dramaId: dto.dramaId,
      episodeId: dto.episodeId,
      itemId: dto.itemId,
      unlockType: _unlockType(dto.unlockType),
      price: dto.price,
      balance: dto.balance,
      reason: dto.reason,
      operationId: dto.operationId,
    );
  }

  EpisodeAccessDecision mapUnlockResultDecision({
    required UnlockEpisodeResponseDto dto,
    required String dramaId,
    required String episodeId,
    required int price,
    required String operationId,
  }) {
    if (dto.decision != null) return mapDecision(dto.decision!);

    final type = switch (dto.result.toLowerCase()) {
      'success' || 'alreadyunlocked' => EpisodeAccessDecisionType.allowPlay,
      'insufficientcoins' => EpisodeAccessDecisionType.showRechargeDialog,
      'membershiprequired' => EpisodeAccessDecisionType.goMembership,
      'unavailable' => EpisodeAccessDecisionType.waitUnlock,
      _ => throw ApiMappingException(
        dtoName: 'UnlockEpisodeResponseDto',
        field: 'result',
        reason: 'unknown unlock result at mapper',
      ),
    };

    return EpisodeAccessDecision(
      type: type,
      dramaId: dramaId,
      episodeId: episodeId,
      itemId: episodeId,
      unlockType: EpisodeUnlockType.coins,
      price: price,
      reason: dto.reason ?? dto.result,
      operationId: operationId,
    );
  }

  EpisodeAccessDecisionType _decisionType(String value) {
    return switch (value) {
      'allowPlay' => EpisodeAccessDecisionType.allowPlay,
      'goMembership' => EpisodeAccessDecisionType.goMembership,
      'showCoinUnlockDialog' => EpisodeAccessDecisionType.showCoinUnlockDialog,
      'showRechargeDialog' => EpisodeAccessDecisionType.showRechargeDialog,
      'autoUnlockAndPlay' => EpisodeAccessDecisionType.autoUnlockAndPlay,
      'waitUnlock' => EpisodeAccessDecisionType.waitUnlock,
      _ => throw ApiMappingException(
        dtoName: 'EpisodeAccessDecisionDto',
        field: 'type',
        reason: 'unknown decision type at mapper',
      ),
    };
  }

  EpisodeUnlockType _unlockType(String value) {
    return switch (value.toLowerCase()) {
      'free' => EpisodeUnlockType.free,
      'membership' || 'member' || 'vip' => EpisodeUnlockType.membership,
      'coins' || 'coin' => EpisodeUnlockType.coins,
      _ => throw ApiMappingException(
        dtoName: 'EpisodeAccessDecisionDto',
        field: 'unlockType',
        reason: 'unknown unlockType at mapper',
      ),
    };
  }
}
