import '../../../../shared/media/media_resource.dart';
import '../../domain/wallet_record.dart';
import '../dto/wallet_consumption_record_dto.dart';
import '../dto/wallet_dto.dart';
import '../dto/wallet_reward_coin_record_dto.dart';
import '../dto/wallet_transaction_record_dto.dart';

/// 钱包远程 DTO 到 domain 的 mapper。
///
/// 这里不做账本计算，只把服务端结构化字段映射成当前 UI 已接收的展示模型；真实余额、
/// 赠币和流水一致性以后端返回为准。
class WalletMapper {
  const WalletMapper();

  WalletData mapWallet(WalletDto dto) {
    return WalletData(
      coins: dto.coinBalance,
      bonus: dto.bonusBalance,
      totalCoin: dto.totalCoin,
      autoUnlockNextEpisode: dto.autoUnlockEnabled,
      transactionRecords: dto.transactionRecords
          .map(mapTransaction)
          .toList(growable: false),
      consumptionRecords: dto.consumptionRecords
          .map(mapConsumption)
          .toList(growable: false),
      coinRecords: dto.rewardCoinRecords.map(mapReward).toList(growable: false),
    );
  }

  WalletRecord mapTransaction(WalletTransactionRecordDto dto) {
    return WalletRecord(
      id: dto.id,
      type: WalletRecordType.transaction,
      title: dto.title ?? _transactionTitle(dto),
      dateLabel: _dateLabel(dto.createdAt),
      trailingLabel: dto.price != null
          ? _priceLabel(dto.price!, dto.currency)
          : dto.amount.toString(),
      showCoinIcon: dto.amount > 0,
      detailLabel: dto.platform,
      trailingSubtitle: dto.status,
    );
  }

  WalletRecord mapConsumption(WalletConsumptionRecordDto dto) {
    return WalletRecord(
      id: dto.id,
      type: WalletRecordType.consumption,
      title: 'EP. ${dto.episodeNumber}',
      subtitle: dto.title,
      dateLabel: _dateLabel(dto.createdAt),
      trailingLabel: dto.sourceType.toLowerCase() == 'ad'
          ? 'AD'
          : '-${dto.amountCoins}',
      trailingSubtitle: dto.sourceType.toLowerCase() == 'ad' ? null : 'Coins',
      posterAssetPath: _fallbackPoster,
      posterResource: _poster(dto.coverUrl),
      consumptionStatus: dto.status.toLowerCase() == 'expired'
          ? WalletConsumptionStatus.expired
          : WalletConsumptionStatus.spent,
    );
  }

  WalletRecord mapReward(WalletRewardCoinRecordDto dto) {
    return WalletRecord(
      id: dto.recordId.toString(),
      type: WalletRecordType.coins,
      title: '${dto.bonusCoin} Reward Coins',
      dateLabel: dto.permanent
          ? '${_dateLabel(dto.startAt)} - Permanent'
          : '${_dateLabel(dto.startAt)} - ${_dateLabel(dto.expireAt)}',
      trailingLabel: dto.status == 1 ? 'Claimed' : 'Check in',
      showCoinIcon: true,
      rewardEnabled: dto.status == 0,
      rewardClaimed: dto.status == 1,
      subtitle: dto.sourceName,
    );
  }

  MediaResource _poster(String? url) {
    if (url != null && url.isNotEmpty) {
      return MediaResource.network(url);
    }
    return const MediaResource.asset(_fallbackPoster);
  }

  String _transactionTitle(WalletTransactionRecordDto dto) {
    if (dto.bonusAmount > 0) {
      return '${dto.amount} Coins + ${dto.bonusAmount} bonus';
    }
    return dto.type.isEmpty ? 'Transaction' : dto.type;
  }

  String _priceLabel(int priceMicros, String? currency) {
    final amount = priceMicros / 1000000;
    final symbol = currency == 'USD' || currency == null ? r'$' : currency;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

const _fallbackPoster = 'assets/images/my_list/cover_1.png';
