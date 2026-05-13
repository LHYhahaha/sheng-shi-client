import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations is missing from context.');
    return localizations!;
  }

  static AppLocalizations maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String get appTitle => _text(en: 'Drama Client', zh: '短剧客户端');
  String get navHome => _text(en: 'Home', zh: '首页');
  String get navForYou => _text(en: 'For you', zh: '推荐');
  String get navMyList => _text(en: 'My list', zh: '片单');
  String get navProfile => _text(en: 'Profile', zh: '我的');
  String get exclusive => _text(en: 'Exclusive', zh: '独家');
  String get feedLoading => _text(en: 'Loading...', zh: '加载中...');
  String get feedEmpty => _text(en: 'There is no content for now~', zh: '暂无内容');
  String get feedLoadFailed => _text(en: 'Load failed', zh: '加载失败');
  String get retry => _text(en: 'Retry', zh: '重试');
  String get myListCollectionTab => _text(en: 'Collection list', zh: '收藏列表');
  String get myListPlayTab => _text(en: 'Play list', zh: '播放列表');
  String get myListChoose => _text(en: 'Choose', zh: '选择');
  String get myListCancel => _text(en: 'Cancel', zh: '取消');
  String get myListEdit => _text(en: 'Edit', zh: '编辑');
  String get myListDelete => _text(en: 'Delete', zh: '删除');
  String get myListEmptyTitle => _text(en: 'Nothing here yet', zh: '暂无内容');
  String get myListEmptyDescription => _text(
    en: 'Saved dramas and watch history will appear here.',
    zh: '收藏的短剧和播放记录会展示在这里。',
  );
  String get profileLogin => _text(en: 'Log in >', zh: '登录 >');
  String get profileGuest => _text(en: 'Guest', zh: '游客');
  String get profileMembershipJoin => _text(en: 'Join Membership', zh: '开通会员');
  String get profileMembership => _text(en: 'Membership', zh: '会员');
  String get profileMembershipSubtitle =>
      _text(en: 'to enjoy all series for free', zh: '免费观看全部短剧');
  String get profileMembershipValidUntil =>
      _text(en: 'Valid time 16/05/26', zh: '有效期至 16/05/26');
  String get profileJoin => _text(en: 'Join', zh: '开通');
  String get profileRenewal => _text(en: 'Renewal', zh: '续费');
  String get profileSeriesBenefit => _text(en: '8K+ series', zh: '8K+ 短剧');
  String get profileDailyPoints => _text(en: 'Daily points', zh: '每日积分');
  String get profileDownload => _text(en: 'Download', zh: '下载');
  String get profileFullHd => _text(en: '1080p', zh: '1080p');
  String get profileCoins => _text(en: 'Coins', zh: '金币');
  String get profileTopUp => _text(en: 'Top Up', zh: '充值');
  String get profileLanguage => _text(en: 'Language', zh: '语言');
  String get playerEpisodes => _text(en: 'Episodes', zh: '选集');
  String get playerShare => _text(en: 'Share', zh: '分享');
  String get playerMore => _text(en: 'More', zh: '更多');
  String get playerDownload => _text(en: 'Download', zh: '下载');
  String get playerSpeed => _text(en: 'Speed', zh: '倍速');
  String get playerSynopsis => _text(en: 'Synopsis', zh: '简介');
  String get playerMoreLikeThis => _text(en: 'More Like This', zh: '猜你喜欢');
  String get playerUnlockNow => _text(en: 'Unlock Now', zh: '立即解锁');
  String get playerMemberUnlock => _text(en: 'Member unlock', zh: '会员解锁');
  String get playerBecomeMember => _text(en: 'Become a member >', zh: '开通会员 >');
  String get playerPlay => _text(en: 'Play', zh: '播放');
  String get playerAutoNext =>
      _text(en: 'Play the next episode automatically', zh: '自动播放下一集');
  String get playerPrice => _text(en: 'Price:', zh: '价格:');
  String get playerBalance => _text(en: 'Balance:', zh: '余额:');
  String get playerFacebook => _text(en: 'Facebook', zh: 'Facebook');
  String get playerWhatsApp => _text(en: 'WhatsApp', zh: 'WhatsApp');
  String get playerMessenger =>
      _text(en: 'Facebook\nMessenger', zh: 'Facebook\nMessenger');
  String get playerInstagram => _text(en: 'Instagram', zh: 'Instagram');
  String get playerSnapchat => _text(en: 'Snapchat', zh: 'Snapchat');

  String myListDeleteCount(int count) {
    return _text(en: 'Delete ($count)', zh: '删除 ($count)');
  }

  String get forYouPlaceholderTitle => navForYou;
  String get forYouPlaceholderDescription =>
      _text(en: 'Short drama playback feed comes in M3.', zh: '短剧播放流将在 M3 接入。');
  String get myListPlaceholderTitle => navMyList;
  String get myListPlaceholderDescription => _text(
    en: 'Collection list and play list come in M4.',
    zh: '收藏列表和播放列表将在 M4 接入。',
  );
  String get profilePlaceholderTitle => navProfile;
  String get profilePlaceholderDescription => _text(
    en: 'Guest/login state, wallet, and membership entries come in M4.',
    zh: '游客/登录态、钱包和会员入口将在 M4 接入。',
  );
  String get storePlaceholderTitle => _text(en: 'Store', zh: '充值');
  String get storePlaceholderDescription => _text(
    en: 'Coin and VIP recharge packages come in M5.',
    zh: '金币和 VIP 充值套餐将在 M5 接入。',
  );
  String get walletPlaceholderTitle => _text(en: 'My Wallet', zh: '钱包');
  String get walletPlaceholderDescription => _text(
    en: 'Balance and wallet actions come in M5.',
    zh: '余额和钱包操作将在 M5 接入。',
  );
  String get membershipPlaceholderTitle => _text(en: 'Membership', zh: '会员');
  String get membershipPlaceholderDescription =>
      _text(en: 'VIP plans and benefits come in M5.', zh: 'VIP 套餐和权益将在 M5 接入。');
  String get languagePlaceholderTitle => _text(en: 'Language', zh: '语言');
  String get languagePlaceholderDescription => _text(
    en: 'Language settings are deferred until after MVP localization.',
    zh: '语言设置将在 MVP 多语言基础完成后接入。',
  );
  String get transactionHistoryPlaceholderTitle =>
      _text(en: 'Transaction history', zh: '交易记录');
  String get transactionHistoryPlaceholderDescription => _text(
    en: 'Wallet transaction records come in M5.',
    zh: '钱包交易记录将在 M5 接入。',
  );
  String get consumptionHistoryPlaceholderTitle =>
      _text(en: 'Consumption history', zh: '消费记录');
  String get consumptionHistoryPlaceholderDescription => _text(
    en: 'Episode unlock and coin consumption records come in M5.',
    zh: '剧集解锁和金币消费记录将在 M5 接入。',
  );
  String get recordCoinsPlaceholderTitle =>
      _text(en: 'Record Coins', zh: '金币记录');
  String get recordCoinsPlaceholderDescription => _text(
    en: 'Check-in and reward coins come in M5.',
    zh: '签到和奖励金币将在 M5 接入。',
  );

  String _text({required String en, required String zh}) {
    return locale.languageCode == 'zh' ? zh : en;
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
