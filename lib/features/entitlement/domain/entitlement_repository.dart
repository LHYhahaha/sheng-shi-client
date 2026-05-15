import 'user_entitlement_state.dart';

/// Entitlement 数据边界。
///
/// Controller 只能通过这个接口读取/修改会员、金币、自动解锁和已解锁状态，不能直接
/// 操作 mock 数据结构。真实接入时，这里会替换为远程权益接口、钱包接口和验单结果的
/// 聚合实现。
abstract interface class EntitlementRepository {
  /// 拉取当前用户权益状态。
  Future<UserEntitlementState> fetchState();

  /// 保存自动金币解锁偏好。
  Future<UserEntitlementState> setAutoUnlockEnabled(bool enabled);

  /// mock 授予会员。
  ///
  /// 真实阶段会员权益必须等待服务端验单/权益刷新，不能只因为客户端支付流程 success
  /// 就直接改本地会员态。
  Future<UserEntitlementState> grantMockMembership({required String source});

  /// mock 增加金币。
  ///
  /// 真实阶段金币余额必须由钱包/订单服务刷新，不能只信客户端支付结果。
  Future<UserEntitlementState> grantMockCoins({
    required int amount,
    required String source,
  });

  /// 用金币解锁单集。
  ///
  /// `operationId` 必须幂等：同一个扣费动作重试不能重复扣金币。真实阶段应由服务端
  /// 根据 operationId/orderId/transactionId 保证幂等。
  Future<UserEntitlementState> unlockEpisodeWithCoins({
    required String dramaId,
    required String episodeId,
    required int price,
    required String operationId,
  });
}
