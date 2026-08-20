import '../../entitlement/domain/episode_unlock_type.dart';
import '../../entitlement/domain/user_entitlement_state.dart';
import '../domain/player_access_presentation.dart';
import '../domain/player_feed.dart';

/// Pure access presentation for feed items (no playback side effects).
class PlayerAccessPresenter {
  const PlayerAccessPresenter({Set<String>? entitlementPlayableItemIds})
    : _entitlementPlayableItemIds = entitlementPlayableItemIds ?? const {};

  final Set<String> _entitlementPlayableItemIds;

  PlayerAccessPresenter withPlayableItem(String itemId) {
    return PlayerAccessPresenter(
      entitlementPlayableItemIds: {..._entitlementPlayableItemIds, itemId},
    );
  }

  /// 撤销当前会话内的临时放行。
  ///
  /// 会员过期、权益刷新或解锁失败后，不能保留旧的 allowPlay 决策；否则播放已经
  /// 被暂停，UI 仍会把锁集渲染为 playable，从而不显示解锁入口。
  PlayerAccessPresenter withoutPlayableItem(String itemId) {
    if (!_entitlementPlayableItemIds.contains(itemId)) {
      return this;
    }
    return PlayerAccessPresenter(
      entitlementPlayableItemIds: {
        ..._entitlementPlayableItemIds.where((id) => id != itemId),
      },
    );
  }

  bool isEntitlementPlayable(PlayerFeedItem item) {
    return !item.episode.isLocked ||
        _entitlementPlayableItemIds.contains(item.id);
  }

  bool isLockedAutoSheetCandidate(PlayerFeedItem item) {
    return item.episode.isLocked &&
        !item.episode.isUnavailable &&
        !isEntitlementPlayable(item);
  }

  PlayerAccessPresentationState presentationFor(
    PlayerFeedItem item,
    UserEntitlementState entitlement,
  ) {
    if (item.episode.isUnavailable) {
      return PlayerAccessPresentationState.unavailable;
    }
    if (isEntitlementPlayable(item)) {
      return PlayerAccessPresentationState.playable;
    }
    if (item.episode.unlockType == EpisodeUnlockType.membership) {
      return PlayerAccessPresentationState.lockedMembership;
    }
    // 仅用于 chrome 展示分档；解锁决策以 EntitlementController.evaluateAccess 为准。
    // bonusBalance 当前不参与扣费，故此处也只比较 coinBalance。
    if (entitlement.coinBalance >= item.episode.requiredCoins) {
      return PlayerAccessPresentationState.lockedCoins;
    }
    return PlayerAccessPresentationState.lockedRecharge;
  }

  PlayerFeedItem playableCopy(PlayerFeedItem item) {
    if (!item.episode.isLocked) {
      return item;
    }
    return item.copyWith(episode: item.episode.copyWith(isLocked: false));
  }
}
