import 'episode_unlock_type.dart';

/// entitlement 对某个剧集访问请求给出的决策类型。
///
/// 这里描述“下一步应该做什么”，而不是播放器状态。PlayerPage 后续只需要把这些
/// 决策映射到播放、会员页、金币确认弹窗或充值弹窗即可。
enum EpisodeAccessDecisionType {
  /// 已具备播放权限，可以交给播放器 open/play。
  allowPlay,

  /// 需要进入会员开通流程。
  goMembership,

  /// 金币足够但未开启自动解锁，需要展示单集金币确认弹窗。
  showCoinUnlockDialog,

  /// 金币不足且不是会员，需要展示充值/会员组合弹窗。
  showRechargeDialog,

  /// 金币足够且开启自动解锁，调用方可以继续执行扣金币并播放。
  autoUnlockAndPlay,

  /// 暂时不能继续，例如不可用、功能未开启、或等待真实服务端结果。
  waitUnlock,
}

/// 单次剧集访问判定结果。
///
/// 这个模型是 Player、Store、Membership、Wallet 之间的“轻量契约”。它只携带
/// 决策所需的业务信息，不携带 UI widget、路由对象或 media session，避免 feature
/// 之间反向依赖。
class EpisodeAccessDecision {
  const EpisodeAccessDecision({
    required this.type,
    required this.dramaId,
    required this.episodeId,
    required this.itemId,
    required this.unlockType,
    this.price,
    this.balance,
    this.reason,
    this.operationId,
  });

  /// 决策类型，调用方根据它决定播放、跳转或展示弹窗。
  final EpisodeAccessDecisionType type;

  /// 剧 id，用于后续扣费、权益查询和回到 pending unlock。
  final String dramaId;

  /// 剧集 id。mock 阶段用它记录已解锁集合；真实阶段应和服务端 episodeId 对齐。
  final String episodeId;

  /// 当前播放 feed item id。
  ///
  /// 同一 episode 可能从不同 feed 入口进入，itemId 用来让播放器恢复当前可见位置。
  final String itemId;

  /// 当前剧集的解锁策略。
  final EpisodeUnlockType unlockType;

  /// 单集金币价格。
  ///
  /// 仅对金币解锁有效。真实价格必须由服务端权益/播放源接口返回，不能依赖客户端默认值。
  final int? price;

  /// 当前账户金币余额快照。
  ///
  /// 用于弹窗展示和测试断言，真实钱包余额仍应以后端刷新为准。
  final int? balance;

  /// 给日志、测试和 UI fallback 使用的原因说明。
  final String? reason;

  /// 幂等操作 id。
  ///
  /// 自动解锁或重试扣金币时必须带同一个 operationId，防止网络重试或按钮重复点击导致
  /// 多次扣费。
  final String? operationId;
}
