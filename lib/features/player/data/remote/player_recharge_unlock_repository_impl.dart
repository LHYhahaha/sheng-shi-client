import '../../../../features/pay/application/iap_price_service.dart';
import '../../../../features/pay/domain/iap_product_info.dart';
import '../../../../features/pay/domain/pay_channel.dart';
import '../dto/player_episode_unlock_dto.dart';
import '../mapper/player_recharge_unlock_mapper.dart';
import '../../domain/player_recharge_unlock_offer.dart';
import '../../domain/player_recharge_unlock_repository.dart';
import 'player_remote_data_source.dart';

/// 播放器充值解锁弹窗的真实数据来源。
///
/// 复用 Store 模块的 API 接口获取套餐数据，并查询 IAP 价格（含促销信息）。
class PlayerRechargeUnlockRepositoryImpl
    implements PlayerRechargeUnlockRepository {
  const PlayerRechargeUnlockRepositoryImpl({
    required this.remoteDataSource,
    required this.iapPriceService,
  });

  final PlayerRemoteDataSource remoteDataSource;
  final IapPriceService iapPriceService;

  @override
  Future<PlayerRechargeUnlockOffer> fetchOffer({
    required String itemId,
    required int requiredCoins,
    bool isMember = false,
  }) async {
    // 1. 获取 API 数据
    final dto = await remoteDataSource.fetchRechargePage();

    // 2. 提取所有需要查询 IAP 的商品 ID
    // 如果用户已是会员，不需要查询会员商品价格
    final channelProductIds = <String>{};
    for (final pkg in dto.coinProducts) {
      if (PayChannel.isGoogle(pkg.payChannel) &&
          pkg.channelProductId.isNotEmpty) {
        channelProductIds.add(pkg.channelProductId);
      }
    }
    if (!isMember) {
      for (final pkg in dto.memberProducts) {
        if (PayChannel.isGoogle(pkg.payChannel) &&
            pkg.channelProductId.isNotEmpty) {
          channelProductIds.add(pkg.channelProductId);
        }
      }
    }

    // 3. 查询 IAP 价格（含促销信息）
    final iapDetails = <String, IapProductInfo>{};
    var isGoogleBillingUnavailable = false;
    if (channelProductIds.isNotEmpty) {
      final billingAvailable = await iapPriceService
          .isGooglePlayBillingAvailable();
      if (!billingAvailable) {
        isGoogleBillingUnavailable = true;
      } else {
        final result = await iapPriceService.queryProductsWithPromo(
          productIds: channelProductIds,
        );
        iapDetails.addAll(result);
      }
    }

    // 4. 映射为 Player 专用模型（IapProductInfo 已一次性组装好促销价、原价、offerToken）
    return PlayerRechargeUnlockMapper.mapToOffer(
      dto,
      iapDetails,
      requiredCoins,
      isMember: isMember,
      isGoogleBillingUnavailable: isGoogleBillingUnavailable,
    );
  }

  @override
  Future<PlayerEpisodeUnlockDto> unlockEpisodeWithCoin({
    required bool autoUnlockNext,
    required int coin,
    required int dramaId,
    required int episodeNo,
    required String shortTitle,
    required String cover,
    required int episodeId,
    required String requestId,
  }) async {
    return remoteDataSource.unlockEpisode(
      autoUnlockNext: autoUnlockNext,
      coin: coin,
      cover: cover,
      dramaId: dramaId,
      episodeId: episodeId,
      episodeNo: episodeNo,
      requestId: requestId,
      shortTitle: shortTitle,
    );
  }
}
