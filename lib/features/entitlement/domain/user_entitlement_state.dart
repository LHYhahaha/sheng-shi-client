import 'episode_unlock_type.dart';

/// 待处理的剧集解锁目标。
///
/// 关闭金币/充值/会员弹窗后，播放器仍需要知道用户刚才想解锁哪一集。这个对象只保留
/// 业务标识，不保存 BuildContext、Route 或 PlayerFeedItem，避免跨层生命周期泄漏。
class PendingEpisodeUnlock {
  const PendingEpisodeUnlock({
    required this.dramaId,
    required this.episodeId,
    required this.itemId,
    required this.unlockType,
    this.price,
    this.operationId,
    this.reason,
  });

  final String dramaId;
  final String episodeId;
  final String itemId;
  final EpisodeUnlockType unlockType;
  final int? price;
  final String? operationId;
  final String? reason;
}

/// 当前用户的权益状态快照。
///
/// 这是 Player/Store/Membership/Wallet 之间共享的业务来源。mock 阶段它由本地
/// repository 维护；真实阶段应由 Auth、钱包、会员和权益接口合成，客户端不能只凭
/// 本地 purchase success 发放会员或金币权限。
class UserEntitlementState {
  const UserEntitlementState({
    required this.isGuest,
    required this.isMember,
    required this.coinBalance,
    required this.autoUnlockEnabled,
    required this.unlockedEpisodeIds,
    this.bonusBalance = 0,
    this.membershipExpiresAt,
    this.pendingOperationId,
    this.serverTime,
    this.refreshReason,
    this.pendingUnlock,
    this.inFlightUnlockEpisodeId,
    this.lastUnlockError,
  });

  const UserEntitlementState.guest()
    : isGuest = true,
      isMember = false,
      coinBalance = 0,
      bonusBalance = 0,
      autoUnlockEnabled = false,
      unlockedEpisodeIds = const <String>{},
      membershipExpiresAt = null,
      pendingOperationId = null,
      serverTime = null,
      refreshReason = null,
      pendingUnlock = null,
      inFlightUnlockEpisodeId = null,
      lastUnlockError = null;

  /// 是否游客。
  ///
  /// MVP 中游客可以看免费内容，但付费/会员内容会被当作非会员处理。未来如果产品要求
  /// 先登录再解锁，应在 entitlement 决策层扩展，不要让 PlayerPage 自己判断。
  final bool isGuest;

  /// 当前账号是否有会员权益。
  ///
  /// 真实会员态必须由服务端权益接口刷新，不能由客户端 mock purchase success 直接推断。
  final bool isMember;

  /// 可消费金币余额。
  ///
  /// 真实余额来自钱包/权益服务；本地扣减只用于 mock 和单测验证幂等逻辑。
  final int coinBalance;

  /// 赠币余额。
  ///
  /// 当前 mock 主要使用 coinBalance；真实钱包/权益接口会区分可消费金币和赠币。
  final int bonusBalance;

  /// 会员过期时间。
  final DateTime? membershipExpiresAt;

  /// 服务端正在处理的权益操作 id。
  final String? pendingOperationId;

  /// 服务端时间，用于促销/权益过期倒计时校准。
  final DateTime? serverTime;

  /// 权益刷新原因。
  final String? refreshReason;

  /// 是否自动解锁金币剧集。
  ///
  /// 这是用户偏好，不代表任何剧集一定能解锁；仍需检查价格、余额、已解锁和功能开关。
  final bool autoUnlockEnabled;

  /// 已解锁的剧集 id 集合。
  ///
  /// mock 阶段只按 episodeId 存储。真实阶段应由服务端返回，且要考虑账号、sourceId、
  /// accessLevel 和跨设备同步。
  final Set<String> unlockedEpisodeIds;

  /// 当前等待用户完成的解锁目标。
  final PendingEpisodeUnlock? pendingUnlock;

  /// 正在执行 mock 扣金币的剧集 id。
  ///
  /// 用于禁用重复动作和测试 in-flight 状态；不要用它表达真实订单状态。
  final String? inFlightUnlockEpisodeId;

  /// 最近一次解锁错误。
  ///
  /// 真实阶段需要拆成错误码、可重试性和服务端 message。MVP 先保留 Object 以兼容 mock。
  final Object? lastUnlockError;

  bool isEpisodeUnlocked(String episodeId) =>
      unlockedEpisodeIds.contains(episodeId);

  UserEntitlementState copyWith({
    bool? isGuest,
    bool? isMember,
    int? coinBalance,
    int? bonusBalance,
    DateTime? membershipExpiresAt,
    String? pendingOperationId,
    DateTime? serverTime,
    String? refreshReason,
    bool? autoUnlockEnabled,
    Set<String>? unlockedEpisodeIds,
    PendingEpisodeUnlock? pendingUnlock,
    String? inFlightUnlockEpisodeId,
    Object? lastUnlockError,
    bool clearPendingUnlock = false,
    bool clearInFlightUnlock = false,
    bool clearLastUnlockError = false,
  }) {
    return UserEntitlementState(
      isGuest: isGuest ?? this.isGuest,
      isMember: isMember ?? this.isMember,
      coinBalance: coinBalance ?? this.coinBalance,
      bonusBalance: bonusBalance ?? this.bonusBalance,
      membershipExpiresAt: membershipExpiresAt ?? this.membershipExpiresAt,
      pendingOperationId: pendingOperationId ?? this.pendingOperationId,
      serverTime: serverTime ?? this.serverTime,
      refreshReason: refreshReason ?? this.refreshReason,
      autoUnlockEnabled: autoUnlockEnabled ?? this.autoUnlockEnabled,
      unlockedEpisodeIds: unlockedEpisodeIds ?? this.unlockedEpisodeIds,
      pendingUnlock: clearPendingUnlock
          ? null
          : pendingUnlock ?? this.pendingUnlock,
      inFlightUnlockEpisodeId: clearInFlightUnlock
          ? null
          : inFlightUnlockEpisodeId ?? this.inFlightUnlockEpisodeId,
      lastUnlockError: clearLastUnlockError
          ? null
          : lastUnlockError ?? this.lastUnlockError,
    );
  }
}
