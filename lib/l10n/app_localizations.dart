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
  String get myListEmptyDescription =>
      _text(en: 'There is no content for now~', zh: '暂无内容');
  String get myListWatchPopular =>
      _text(en: 'Watch popular dramas', zh: '观看热门短剧');
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
  String get profileWallet => _text(en: 'Wallet >', zh: '钱包 >');
  String get profileLanguage => _text(en: 'Language', zh: '语言');
  String get authDeviceLogin => _text(en: 'Continue with Device', zh: '使用设备登录');
  String get authGoogleLogin =>
      _text(en: 'Sign in with Google', zh: '使用 Google 登录');
  String get authFacebookLogin =>
      _text(en: 'Sign in with Facebook', zh: '使用 Facebook 登录');
  String get authClaimCoins => _text(en: 'Claim 150 coins!', zh: '领取 150 金币!');
  String get authTermsCopy => _text(
    en: 'By continuing, you agree to our Terms of Use & Privacy Policy.',
    zh: '继续即表示你同意我们的用户协议和隐私政策。',
  );
  String get authLoadFailed =>
      _text(en: 'Login failed. Please try again.', zh: '登录失败，请重试。');
  String get authAccountActions => _text(en: 'Account actions', zh: '账号操作');
  String get authAccountTitle => _text(en: 'Account', zh: '账号');
  String get authLogout => _text(en: 'Log out', zh: '退出登录');
  String get authDeleteAccount => _text(en: 'Delete account', zh: '注销账号');
  String get authDeleteAccountMessage => _text(
    en: 'This is a mock delete account confirmation for MVP testing.',
    zh: '当前为 MVP 测试用注销账号确认，不会删除真实数据。',
  );
  String get authDeleteAccountConfirm => _text(en: 'Delete', zh: '注销');
  String get walletTitle => _text(en: 'My Wallet', zh: '钱包');
  String get walletCoins => _text(en: 'Coins', zh: '金币');
  String get walletBonus => _text(en: 'Bonus', zh: '赠币');
  String get walletTopUp => _text(en: 'Top Up', zh: '充值');
  String get walletAutoUnlockNextEpisode =>
      _text(en: 'Anto-unlock the next episode', zh: '自动解锁下一集');
  String get transactionHistoryTitle =>
      _text(en: 'Transaction history', zh: '交易记录');
  String get consumptionHistoryTitle =>
      _text(en: 'Consumption history', zh: '消费记录');
  String get recordCoinsTitle => _text(en: 'Record Coins', zh: '金币记录');
  String get storeTitle => _text(en: 'Store', zh: '商店');
  String get storeRestore => _text(en: 'Restore', zh: '恢复购买');
  String get storeRestoreUnavailable => _text(
    en: 'Restore is unavailable in mock mode.',
    zh: '当前为模拟模式，暂不支持恢复购买。',
  );
  String get storeTips => _text(en: 'Tips', zh: '提示');
  String get storeBuyNow => _text(en: 'Buy Now', zh: '立即购买');
  String get storeSelected => _text(en: 'Selected', zh: '已选择');
  String get storeConfirmPurchase => _text(en: 'Confirm purchase', zh: '确认购买');
  String get storeConfirm => _text(en: 'Confirm', zh: '确认');
  String get storeCancel => _text(en: 'Cancel', zh: '取消');
  String get storeClose => _text(en: 'Done', zh: '完成');
  String get storePurchaseProcessing =>
      _text(en: 'Processing mock purchase...', zh: '正在模拟购买...');
  String get storePurchaseSuccess =>
      _text(en: 'Mock purchase completed.', zh: '模拟购买已完成。');
  String get storePurchaseCancelled =>
      _text(en: 'Mock purchase cancelled.', zh: '模拟购买已取消。');
  String get storeMockPaymentNote => _text(
    en: 'This is a mock confirmation for MVP testing.',
    zh: '当前为 MVP 测试用模拟确认弹窗。',
  );
  String get membershipBenefits => _text(en: 'VIP Benefits', zh: '会员权益');
  String get membershipBuyNow => _text(en: 'Join Now', zh: '立即开通');
  String get membershipConfirmPurchase =>
      _text(en: 'Confirm membership', zh: '确认开通会员');
  String get membershipMockPaymentNote => _text(
    en: 'This is a mock membership confirmation for MVP testing.',
    zh: '当前为 MVP 测试用会员模拟确认弹窗。',
  );
  String get walletHistoryEmpty =>
      _text(en: 'There are no records yet.', zh: '暂无记录');
  String get walletSpent => _text(en: 'Spent', zh: '已使用');
  String get walletExpired => _text(en: 'Expired', zh: '已过期');
  String get walletCheckIn => _text(en: 'Check in', zh: '签到');
  String get walletCoinsUnit => _text(en: 'Coins', zh: '金币');
  String get playerEpisodes => _text(en: 'Episodes', zh: '选集');
  String get playerShare => _text(en: 'Share', zh: '分享');
  String get playerMore => _text(en: 'More', zh: '更多');
  String get playerDownload => _text(en: 'Download', zh: '下载');
  String get playerWatchNow => _text(en: 'Watch Now', zh: '立即观看');
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
  String get playerFeedEmpty =>
      _text(en: 'No episodes available yet.', zh: '暂无可播放剧集');
  String get playerFeedLoadFailed =>
      _text(en: 'Player failed to load.', zh: '播放内容加载失败');
  String get playerEpisodeUnavailable =>
      _text(en: 'This episode is unavailable.', zh: '本集暂不可播放');
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
  String get transactionHistoryPlaceholderTitle => transactionHistoryTitle;
  String get transactionHistoryPlaceholderDescription => _text(
    en: 'Wallet transaction records come in M5.',
    zh: '钱包交易记录将在 M5 接入。',
  );
  String get consumptionHistoryPlaceholderTitle => consumptionHistoryTitle;
  String get consumptionHistoryPlaceholderDescription => _text(
    en: 'Episode unlock and coin consumption records come in M5.',
    zh: '剧集解锁和金币消费记录将在 M5 接入。',
  );
  String get recordCoinsPlaceholderTitle => recordCoinsTitle;
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
