import '../../domain/episode_access_decision.dart';
import '../../domain/episode_unlock_type.dart';
import '../../domain/user_entitlement_state.dart';
import '../dto/episode_access_decision_dto.dart';
import '../dto/unlock_episode_response_dto.dart';
import '../dto/user_entitlement_state_dto.dart';

/// Entitlement 远程 DTO 到 domain 的 mapper。
///
/// 真实权益状态必须以后端为准。mapper 只负责字段转换，不在客户端重新解释支付成功、
/// 会员有效期或金币扣费结果。
class EntitlementMapper {
  const EntitlementMapper();

  UserEntitlementState mapState(UserEntitlementStateDto dto) {
    return UserEntitlementState(
      isGuest: dto.isGuest,
      isMember: dto.isMember,
      coinBalance: dto.coinBalance,
      bonusBalance: dto.bonusBalance,
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

    final type = switch (dto.result) {
      'success' || 'alreadyUnlocked' => EpisodeAccessDecisionType.allowPlay,
      'insufficientCoins' => EpisodeAccessDecisionType.showRechargeDialog,
      'membershipRequired' => EpisodeAccessDecisionType.goMembership,
      'unavailable' => EpisodeAccessDecisionType.waitUnlock,
      _ => EpisodeAccessDecisionType.waitUnlock,
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
    switch (value) {
      case 'allowPlay':
        return EpisodeAccessDecisionType.allowPlay;
      case 'goMembership':
        return EpisodeAccessDecisionType.goMembership;
      case 'showCoinUnlockDialog':
        return EpisodeAccessDecisionType.showCoinUnlockDialog;
      case 'showRechargeDialog':
        return EpisodeAccessDecisionType.showRechargeDialog;
      case 'autoUnlockAndPlay':
        return EpisodeAccessDecisionType.autoUnlockAndPlay;
      case 'waitUnlock':
      default:
        return EpisodeAccessDecisionType.waitUnlock;
    }
  }

  EpisodeUnlockType _unlockType(String value) {
    switch (value) {
      case 'free':
        return EpisodeUnlockType.free;
      case 'membership':
        return EpisodeUnlockType.membership;
      case 'coins':
      default:
        return EpisodeUnlockType.coins;
    }
  }
}
