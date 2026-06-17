import '../core/i18n/ui_text.dart';

/// Remote i18n JSON text specification.
///
/// Each entry keeps the server key and local fallbacks together, so feature
/// code can reference one stable catalog item instead of repeating strings.
class RemoteTextSpec {
  const RemoteTextSpec({
    required this.key,
    required this.fallbackEn,
    required this.fallbackZh,
  });

  final String key;
  final String fallbackEn;
  final String fallbackZh;

  UiText uiText([Map<String, Object?> args = const {}]) {
    return UiText.key(
      key,
      fallbackEn: fallbackEn,
      fallbackZh: fallbackZh,
      args: args,
    );
  }
}

abstract final class RemoteTexts {
  static const appCommonUnitCoin = RemoteTextSpec(
    key: 'app.common.unit.coin',
    fallbackEn: 'Coins',
    fallbackZh: '金币',
  );

  static const consumptionHistoryEpisodeIndex = RemoteTextSpec(
    key: 'consumption_history.item.episode_index',
    fallbackEn: 'Episode {index}',
    fallbackZh: '第 {index} 集',
  );

  static const consumptionHistoryCoins = RemoteTextSpec(
    key: 'consumption_history.unit.coins',
    fallbackEn: 'Coins',
    fallbackZh: '金币',
  );

  static const transactionHistoryTitle = RemoteTextSpec(
    key: 'transaction_history.title',
    fallbackEn: 'Transaction',
    fallbackZh: '交易',
  );

  static const walletRecordSourceAd = RemoteTextSpec(
    key: 'wallet.record.source.ad',
    fallbackEn: 'AD',
    fallbackZh: '广告',
  );

  static const walletRecordRewardCoins = RemoteTextSpec(
    key: 'wallet.record.reward_coins',
    fallbackEn: '{count} Reward Coins',
    fallbackZh: '{count} 奖励金币',
  );

  static const walletRecordTransactionCoinsBonus = RemoteTextSpec(
    key: 'wallet.record.transaction.coins_bonus',
    fallbackEn: '{coins} Coins + {bonus} bonus',
    fallbackZh: '{coins} 金币 + {bonus} 赠送',
  );
}
