import '../../../../core/i18n/ui_text.dart';
import '../../../../l10n/remote_texts.dart';
import '../../../../shared/media/media_resource.dart';
import '../../domain/wallet_record.dart';
import '../dto/wallet_consumption_record_dto.dart';
import '../dto/wallet_dto.dart';
import '../dto/wallet_reward_coin_record_dto.dart';
import '../dto/wallet_transaction_record_dto.dart';

/// Wallet remote DTO to domain mapper.
///
/// This layer only maps structured remote fields into the current domain
/// display model. Fixed client copy is represented as [UiText] specs and is
/// resolved by the presentation layer with the current locale.
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
      title: dto.title == null
          ? _transactionTitle(dto)
          : UiText.raw(dto.title!),
      dateLabel: _dateYearToDayLabel(dto.createdAt),
      trailingLabel: UiText.raw(dto.amountText ?? ''),
      showCoinIcon: dto.coinAmount + dto.bonusAmount > 0,
      detailLabel: dto.platform == null ? null : UiText.raw(dto.platform!),
      trailingSubtitle: UiText.raw(dto.status),
      productType: dto.productType,
      memberPeriodType: dto.memberPeriodType,
      coin: dto.coinAmount,
      bonusCoin: dto.bonusAmount,
      amountText: dto.amountText,
    );
  }

  WalletRecord mapConsumption(WalletConsumptionRecordDto dto) {
    final isAd = dto.sourceType.toLowerCase() == 'ad';

    return WalletRecord(
      id: dto.id,
      type: WalletRecordType.consumption,
      title: RemoteTexts.consumptionHistoryEpisodeIndex.uiText({
        'index': dto.episodeNumber,
      }),
      subtitle: UiText.raw(dto.title),
      dateLabel: _dateLabel(dto.createdAt),
      trailingLabel: isAd
          ? RemoteTexts.walletRecordSourceAd.uiText()
          : UiText.raw('-${dto.amountCoins}'),
      trailingSubtitle: isAd
          ? null
          : RemoteTexts.consumptionHistoryCoins.uiText(),
      sourceType: dto.sourceType,
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
      title: RemoteTexts.walletRecordRewardCoins.uiText({
        'count': dto.bonusCoin,
      }),
      dateLabel:
          '${_dateYearToDayLabel(dto.startAt)} - ${_dateYearToDayLabel(dto.expireAt)}',
      trailingLabel: UiText.raw(dto.status.toString()),
      showCoinIcon: true,
      rewardEnabled: dto.status == 0,
      rewardClaimed: dto.status == 1,
      subtitle: UiText.raw(dto.sourceName),
    );
  }

  MediaResource _poster(String? url) {
    if (url != null && url.isNotEmpty) {
      return MediaResource.network(url);
    }
    return const MediaResource.asset(_fallbackPoster);
  }

  UiText _transactionTitle(WalletTransactionRecordDto dto) {
    if (dto.bonusAmount > 0) {
      return RemoteTexts.walletRecordTransactionCoinsBonus.uiText({
        'coins': dto.coinAmount,
        'bonus': dto.bonusAmount,
      });
    }

    return dto.type.isEmpty
        ? RemoteTexts.transactionHistoryTitle.uiText()
        : UiText.raw(dto.type);
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  String _dateYearToDayLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

const _fallbackPoster = 'assets/images/my_list/cover_1.png';
