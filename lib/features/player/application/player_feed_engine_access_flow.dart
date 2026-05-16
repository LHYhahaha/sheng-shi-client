/// 引擎解析权益后建议 PlayerPage 展示的 sheet（仅 UI host 负责 showModal）。
enum PlayerOverlaySheetIntent { none, coinUnlock, rechargeUnlock, membership }

/// 解锁/充值流程引擎结果（供 Page 展示 sheet 或 toast）。
class PlayerUnlockFlowResult {
  const PlayerUnlockFlowResult({
    this.sheetIntent = PlayerOverlaySheetIntent.none,
    this.didAutoUnlock = false,
    this.didActivateMembership = false,
  });

  final PlayerOverlaySheetIntent sheetIntent;
  final bool didAutoUnlock;
  final bool didActivateMembership;
}
