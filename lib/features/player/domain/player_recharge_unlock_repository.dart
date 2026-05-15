import 'player_recharge_unlock_offer.dart';

/// Entitlement 解锁弹窗的数据仓库边界。
///
/// 这里不是 Store/Membership 的普通商品页接口，而是“当前剧集因金币不足需要解锁”
/// 的组合报价接口。真实服务端应根据 episode、账号余额、会员态和地区返回可购买项。
abstract interface class PlayerRechargeUnlockRepository {
  Future<PlayerRechargeUnlockOffer> fetchOffer({
    required String itemId,
    required int requiredCoins,
  });
}
