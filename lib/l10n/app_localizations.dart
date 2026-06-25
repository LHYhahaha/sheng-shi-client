import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/i18n/ui_text.dart';
import 'remote_texts.dart';

/// 应用固定 UI 文案的轻量本地化表。
///
/// 这里覆盖的是客户端 chrome、按钮、错误态等固定语言包，不承载剧名、简介、剧集
/// 等内容多语言。内容多语言应来自内容接口字段或服务端文案策略。
///
/// 支持远程语言包：优先使用远程 JSON 中的 key，找不到时 fallback 到本地硬编码文案，
/// 最后 fallback 到 key 本身（仅开发环境）。
class AppLocalizations {
  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// 当前用于取文案的 Locale。
  ///
  /// 只按 languageCode 切换固定 UI 文案；内容多语言不走这里。
  final Locale locale;

  /// 静态变量：远程语言包的 key-value 映射。
  ///
  /// 由 I18nController 在语言包加载成功后设置。
  /// 所有 AppLocalizations 实例共享此映射。
  static Map<String, dynamic>? _remoteStrings;

  /// 设置远程语言包。
  ///
  /// 由 I18nController 在语言包加载成功后调用。
  static void setRemoteStrings(Map<String, dynamic>? strings) {
    _remoteStrings = strings;
  }

  /// 获取远程语言包。
  static Map<String, dynamic>? get remoteStrings => _remoteStrings;

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

  /// 从远程语言包中查找文案。
  ///
  /// 查找顺序：
  /// 1. 远程语言包（如果已加载）
  /// 2. 本地硬编码文案（en/zh）
  /// 3. key 本身（仅开发环境，方便调试）
  String _remoteText(String key, {required String en, required String zh}) {
    // 1. 尝试从远程语言包获取
    if (AppLocalizations._remoteStrings != null &&
        AppLocalizations._remoteStrings!.containsKey(key)) {
      final value = AppLocalizations._remoteStrings![key];
      if (value is String && value.isNotEmpty) {
        // 将 JSON 中的字面 "\n" 转换为真正的换行符
        return value.replaceAll(r'\n', '\n');
      }
    }

    // 2. 使用本地硬编码文案
    final text = locale.languageCode == 'zh' ? zh : en;

    // 3. 开发环境下如果文本为空，返回 key（方便调试）
    if (text.isEmpty && kDebugMode) {
      return key;
    }

    return text;
  }

  String resolveRemoteText(
    RemoteTextSpec spec, {
    Map<String, Object?> args = const {},
  }) {
    var value = _remoteText(spec.key, en: spec.fallbackEn, zh: spec.fallbackZh);
    return _interpolate(value, args);
  }

  String resolveUiText(UiText text) {
    final rawValue = text.rawValue;
    if (rawValue != null) {
      return rawValue;
    }

    final key = text.key;
    if (key == null || key.isEmpty) {
      return '';
    }

    var value = _remoteText(key, en: text.fallbackEn, zh: text.fallbackZh);
    return _interpolate(value, text.args);
  }



  String _interpolate(String value, Map<String, Object?> args) {
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    if (args.containsKey('index')) {
      value = value.replaceAll('X', args['index'].toString());
    }
    return value;
  }

  String _replaceWords( {required String removeWord, required String word ,required String originWord}){
    String text = "";
    if(originWord.contains(removeWord)){
      text = originWord.replaceAll(removeWord, word);
      return text;
    }
    return originWord;
  }

  // ── 通用 ─────────────────────────────────────────────
  String get appTitle =>
      _remoteText('appTitle', en: 'NovaShort', zh: 'NovaShort');

  String get retry => _remoteText('common.action.retry', en: 'Retry', zh: '重试');

  String get loading =>
      _remoteText('common.status.loading', en: 'Loading', zh: '加载中');

  String get noData =>
      _remoteText('common.status.no_data', en: 'No data', zh: '暂无数据');

  String get emptyNoDramas => _remoteText(
    'home.empty.no_dramas',
    en: 'No dramas yet',
    zh: '暂无短剧',
  );

  String get paymentModalMethodGooglePay => _remoteText(
    'payment_modal.method.google_pay',
    en: 'Google Pay',
    zh: 'Google Pay',
  );
  String get paymentModalOrderDetails => _remoteText(
    'payment_modal.order.details',
    en: 'Order details',
    zh: '订单详情',
  );

  String get paymentModalAmountTotal =>
      _remoteText('payment_modal.amount.total', en: 'Total', zh: '合计');

  String get appCommonLegalPrivacyPolicy => _remoteText(
    'app.common.legal.privacy_policy',
    en: 'Privacy Policy',
    zh: '隐私政策',
  );

  String get appCommonLegalTermsOfUse => _remoteText(
    'app.common.legal.terms_of_use',
    en: 'Terms of Use',
    zh: '使用条款',
  );

  String get edit => _remoteText('common.action.edit', en: 'Edit', zh: '编辑');

  String get autoUnlockNext => _remoteText(
    'app.common.setting.auto_unlock_next',
    en: 'Play the next episode automatically',
    zh: '自动播放下一集',
  );

  // ── 导航 ─────────────────────────────────────────────
  String get navHome => _remoteText('home.nav.home', en: 'Home', zh: '首页');

  String get navForYou =>
      _remoteText('home.nav.recommend', en: 'For you', zh: '推荐');

  String get navMyList =>
      _remoteText('home.nav.my_list', en: 'My list', zh: '我的收藏');

  String get navProfile => _remoteText('home.nav.profile', en: 'Me', zh: '我的');

  String get navRewards =>
      _remoteText('home.nav.rewards', en: 'Rewards', zh: '奖励');

  String get navGame => _remoteText('home.nav.game', en: 'Game', zh: '游戏');

  String get navMember =>
      _remoteText('home.nav.member', en: 'Member', zh: '会员');

  // ── 首页 Feed ─────────────────────────────────────────────

  String get feedLoadFailed =>
      _remoteText('common.action.retry', en: 'Retry', zh: '重试');

  String get feedNoMore =>
      _remoteText('home.state.no_more', en: 'No more content', zh: '没有更多了');

  String get exclusive =>
      _remoteText('home.state.exclusive', en: 'VIP', zh: 'VIP');

  // ── 片单 My List ─────────────────────────────────────────────
  String get myListCollectionTab =>
      _remoteText('my_list.tab.following', en: 'Following', zh: '在追');

  String get myListPlayTab =>
      _remoteText('my_list.tab.history', en: 'Play list', zh: '观看历史');

  String get myListChoose =>
      _remoteText('my_list.action.select', en: 'Choose', zh: '选择');

  String get myListCancel =>
      _remoteText('my_list.action.cancel', en: 'Cancel', zh: '取消');

  String get myListDelete =>
      _remoteText('my_list.action.remove', en: 'Delete', zh: '删除');

  String  myListEpisode(String text) =>
      _replaceWords(
          removeWord: 'X',
          word: text,
          originWord: _remoteText('my_list.episode_index', en: 'EP.X', zh: '第X集'));

  String  myListEpisode2(String text) =>
      _replaceWords(
          removeWord: 'X',
          word: text,
          originWord: _remoteText('my_list.episode_index2', en: 'EP.X', zh: 'X集'));

  String get myListEmptyTitle => _remoteText(
    'my_list.empty.following',
    en: 'Nothing here yet',
    zh: '暂无内容',
  );

  String get myListEmptyDescription => _remoteText(
    'my_list.empty.following',
    en: 'There is no content for now~',
    zh: '暂无内容',
  );

  String get myListWatchPopular => _remoteText(
    'my_list.empty.following',
    en: 'Watch popular dramas',
    zh: '观看热门短剧',
  );

  // String myListDeleteCount(int count) => _remoteText(
  //   'my_list.action.remove',
  //   en: 'Delete ($count)',
  //   zh: '删除 ($count)',
  // );

  String get myListDramaOffShelf => _remoteText(
    'my_list.toast.drama_off_shelf',
    en: 'This drama has been taken down and is temporarily unavailable.',
    zh: '该短剧已下架，暂时无法观看',
  );

  String get myListEmptyFollowing => _remoteText(
    'my_list.empty.following',
    en: 'No followed dramas yet. Go explore Home.',
    zh: '暂无在追剧集，去首页逛逛吧',
  );

  String get myListEmptyHistory => _remoteText(
    'my_list.empty.history',
    en: 'No watch history yet. Go explore Home.',
    zh: '暂无观看历史，去首页逛逛吧',
  );

  // ── 个人中心 Profile ─────────────────────────────────────────────
  String get profileLogin =>
      _remoteText('profile.user.login', en: 'Log in >', zh: '登录');

  String get profileCopySuccess =>
      _remoteText('profile.toast.copy_success', en: 'ID copied', zh: 'ID已复制');

  String get profileGuest => _remoteText('', en: 'Guest', zh: '游客');

  String get profileVipCardMembershipJoin =>
      _remoteText('profile.vip_card.join', en: 'Join Membership', zh: '开通会员');

  String get profileVipCardMembership =>
      _remoteText('profile.vip_card.membership', en: 'Membership', zh: '会员');

  String get profileMembershipValidUntil => _remoteText(
    'profile.vip_card.valid_until',
    en: 'Valid Until',
    zh: '到期时间',
  );

  String get profileBenefitsIntro => _remoteText(
    'profile.vip_card.benefits_intro',
    en: 'Enjoy these exclusive benefits',
    zh: '尊享以下专属权益',
  );

  String get profileSeriesBenefit => _remoteText(
    'profile.vip_card.benefit.series',
    en: '8K+ series',
    zh: '8K+ 短剧',
  );

  String get profileDailyPoints => _remoteText(
    'profile.vip_card.benefit.daily_points',
    en: 'Daily points',
    zh: '每日积分',
  );

  String get profileDownload => _remoteText(
    'profile.vip_card.benefit.download',
    en: 'Download',
    zh: '下载',
  );

  String get profileJoin =>
      _remoteText('profile.button.join', en: 'Join', zh: '开通');

  String get profileFullHd =>
      _remoteText('profile.vip_card.benefit.hd', en: '1080p', zh: '1080p');

  String get profileCoins =>
      _remoteText('profile.wallet.coins', en: 'Coins', zh: '金币');

  String get profileWallet =>
      _remoteText('profile.wallet.wallet', en: 'Wallet >', zh: '钱包 >');

  String get profileTopUp =>
      _remoteText('profile.button.top_up', en: 'Top Up', zh: '充值');

  String get profileLanguage =>
      _remoteText('profile.menu.language', en: 'Language', zh: '语言');

  String get profileSettings =>
      _remoteText('profile.menu.settings', en: 'Settings', zh: '设置');

  String get languagePageTitle =>
      _remoteText('language_page.title.language', en: 'Language', zh: '语言');

  String get languagePageButton =>
      _remoteText('language_page.button.done', en: 'Done', zh: '完成');

  String get profileMember =>
      _remoteText('profile.user.member', en: 'Member', zh: '会员');

  String get profileRenewal =>
      _remoteText('membership_page.plan.monthly', en: 'Renewal', zh: '续费');

  // ── 设置 Settings ─────────────────────────────────────────────
  String get settingsTitle =>
      _remoteText('settings.title', en: 'Settings', zh: '设置');

  String get settingsButtonLogout =>
      _remoteText('settings.button.logout', en: 'Log Out', zh: '登出');
  String get settingsDeleteAccount => _remoteText(
    'settings.entry.delete_account',
    en: 'Delete Account',
    zh: '账号注销',
  );

  String get settingsUserAgreement => _remoteText(
    'app.common.legal.user_agreement',
    en: 'User Agreement',
    zh: '用户协议',
  );

  String get settingsPrivacyPolicy => _remoteText(
    'app.common.legal.privacy_policy',
    en: 'Privacy Policy',
    zh: '隐私政策',
  );

  String get settingsToastLoggedOut =>
      _remoteText('settings.toast.logged_out', en: 'Logged out', zh: '已退出登录');

  // ── 账号注销 Account Cancellation ─────────────────────────────────────────────
  String get accountCancellationTitle =>
      _remoteText('delete_account.title', en: 'Delete Account', zh: '账号注销');

  String get accountCancellationDescription => _remoteText(
    'delete_account.notice.top',
    en: 'Please confirm the information to be deleted:',
    zh: '请确认将删除以下信息：',
  );

  String get accountCancellationInfoPersonalTitle => _remoteText(
    'delete_account.checklist.personal_title',
    en: 'Personal Information',
    zh: '个人信息',
  );

  String get accountCancellationInfoPersonalSubtitle => _remoteText(
    'delete_account.checklist.personal_desc',
    en: 'Your personal information, including email address and nickname, will be deleted.',
    zh: '您的个人信息（邮箱地址和昵称）将被删除',
  );

  String get accountCancellationInfoAccountBalanceTitle => _remoteText(
    'delete_account.checklist.balance_title',
    en: 'Account Balance',
    zh: '账号资产',
  );

  String get accountCancellationInfoAccountBalanceSubtitle => _remoteText(
    'delete_account.checklist.balance_desc',
    en: 'Consumption history will be deleted',
    zh: '消费记录将被删除',
  );

  String get accountCancellationInfoYourBalanceTitle => _remoteText(
    'delete_account.checklist.your_balance_title',
    en: 'Your Balance',
    zh: '你的余额',
  );

  String get accountCancellationInfoYourBalanceSubtitle => _remoteText(
    'delete_account.checklist.your_balance_desc',
    en: 'Your coin balance is zero',
    zh: '你的金币余额为 0',
  );

  String get accountCancellationInfoMemberBenefitsTitle => _remoteText(
    'delete_account.checklist.member_title',
    en: 'Member Benefits',
    zh: '会员权益',
  );

  String get accountCancellationInfoMemberBenefitsSubtitle => _remoteText(
    'delete_account.checklist.member_desc',
    en: 'You are not a member',
    zh: '你当前还不是会员',
  );

  String get accountCancellationInfoThirdPartyTitle => _remoteText(
    'delete_account.checklist.third_party_title',
    en: 'Third-party Account Information',
    zh: '第三方账号信息',
  );

  String get accountCancellationRiskLogoutDevices => _remoteText(
    'delete_account.notice.bottom',
    en: 'To ensure proper access, please log out from this account on other devices. ',
    zh: '为确保正常访问，请先在其他设备退出登录。',
  );

  String get accountCancellationRiskDeletionFinal => _remoteText(
    'delete_account.notice2.bottom',
    en: 'All information in this account will be deleted and cannot be recovered.',
    zh: '本账号所有信息将被删除且无法找回。',
  );

  String get accountCancellationAcceptRisk => _remoteText(
    'delete_account.agreement.risk',
    en: 'I accept the risk',
    zh: '我接受风险',
  );

  String get accountCancellationDeleteButtonReady => _remoteText(
    'delete_account.button.confirm_deletion',
    en: 'Confirm Deletion',
    zh: '确认删除',
  );

  String get accountCancellationConfirmTitle => _remoteText(
    'delete_account.confirm.title',
    en: 'Delete account?',
    zh: '确认删除账号？',
  );

  String get accountCancellationConfirmMessage => _remoteText(
    'delete_account.confirm.message',
    en: 'Deleted account data cannot be recovered. Do you want to continue?',
    zh: '删除后账号信息将无法找回，请确认是否继续。',
  );

  String get accountCancellationConfirmCancel =>
      _remoteText('delete_account.confirm.cancel', en: 'Cancel', zh: '取消');

  String get accountCancellationConfirmDelete => _remoteText(
    'delete_account.confirm.confirm',
    en: 'Confirm delete',
    zh: '确认删除',
  );

  String get accountCancellationSuccess => _remoteText(
    'settings.toast.logged_out',
    en: 'Account deleted',
    zh: '账号已删除',
  );

  String get deleteAccountToastCoinsSpentRequired => _remoteText(
    'delete_account.toast.coins_spent_required',
    en: 'You can delete your account after all purchased coins are spent.',
    zh: '充值金币消耗完毕才可注销',
  );

  String get accountDeletionRejectedActiveMembership => _remoteText(
    'You can delete your account after your membership expires.',
    en: 'Membership must be expired',
    zh: '会员到期后才可注销',
  );

  // ── 认证 Auth ─────────────────────────────────────────────
  String get authDeviceLogin => _remoteText(
    'login.button.facebook',
    en: 'Continue with Device',
    zh: '使用设备登录',
  );

  String get authGoogleLogin => _remoteText(
    'login.button.facebook',
    en: 'Sign in with Google',
    zh: '使用 Google 登录',
  );

  String get authFacebookLogin => _remoteText(
    'login.button.facebook',
    en: 'Sign in with Facebook',
    zh: '使用 Facebook 登录',
  );

  String get authClaimCoins => _remoteText(
    'claim_coins.title',
    en: 'Claim 150 coins!',
    zh: '领取 150 金币!',
  );

  String get authTermsCopy => _remoteText(
    'login.agreement.notice',
    en: 'By continuing, you agree to our Terms of Use and Privacy Policy.',
    zh: '继续即表示您同意我们的使用条款和隐私政策',
  );

  String get loginAgreementPrefix => _remoteText(
    'login.agreement.prefix',
    en: 'By continuing, you agree to our ',
    zh: '继续即表示您同意我们的',
  );

  String get loginAgreementConnector =>
      _remoteText('login.agreement.connector', en: ' & ', zh: '和');

  String get loginAgreementSuffix =>
      _remoteText('login.agreement.suffix', en: '.', zh: '。');

  String get authLoginRequiredMessage => _remoteText(
    'app',
    en: 'Please bind your phone number first',
    zh: '请先绑定手机号',
  );

  String get authSessionExpiredMessage =>
      _remoteText('login.toast.canceled', en: 'Session expired', zh: '会话已过期');

  String get authLogoutFailed => _remoteText(
    'settings.toast.logged_out',
    en: 'Logout failed',
    zh: '退出登录失败',
  );

  String get authLogoutSuccess => _remoteText(
    'settings.toast.logout_success',
    en: 'Account logged out successfully',
    zh: '退出账号成功',
  );

  String get authDeleteAccountFailed => _remoteText(
    'login.toast.failed_retry',
    en: 'Delete account failed',
    zh: '注销账号失败',
  );

  String get authAccountActions => _remoteText(
    'settings.entry.delete_account',
    en: 'Account actions',
    zh: '账号操作',
  );

  String get authAccountTitle =>
      _remoteText('settings.title', en: 'Account', zh: '账号');

  String get authLogout =>
      _remoteText('settings.button.logout', en: 'Log out', zh: '退出登录');

  String get authDeleteAccount => _remoteText(
    'settings.entry.delete_account',
    en: 'Delete account',
    zh: '注销账号',
  );

  String get authDeleteAccountConfirm => _remoteText(
    'delete_account.button.confirm_deletion',
    en: 'Delete',
    zh: '注销',
  );

  String get authLoadFailed => _remoteText(
    'login.toast.failed_retry',
    en: 'Login failed. Please try again.',
    zh: '登录失败，请重试。',
  );

  String get authLoginCanceled => _remoteText(
    'login.toast.canceled',
    en: 'Login cancelled',
    zh: '\u767b\u5f55\u5df2\u53d6\u6d88',
  );

  String get authLoginFailedRetryLater => _remoteText(
    'login.toast.failed_retry_later',
    en: 'Login failed. Please try again later.',
    zh: '\u767b\u5f55\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5',
  );

  // ── 钱包 Wallet ─────────────────────────────────────────────
  String get walletTitle =>
      _remoteText('wallet.title.my_wallet', en: 'My Wallet', zh: '钱包');

  String get walletCoins =>
      _remoteText('wallet.balance.coins', en: 'Coins', zh: '金币');

  String get walletBonus =>
      _remoteText('wallet.balance.bonus_coins', en: 'Reward Coins', zh: '奖励金币');

  String get walletTopUp =>
      _remoteText('wallet.button.top_up', en: 'Top Up', zh: '充值');

  String get walletMenuTransactionHistory => _remoteText(
    'wallet.menu.transaction_history',
    en: 'Transaction History',
    zh: '充值记录',
  );

  String get walletMenuConsumptionHistory => _remoteText(
    'wallet.menu.consumption_history',
    en: 'Consumption History',
    zh: '消耗记录',
  );

  String get walletMenuClaimCoins =>
      _remoteText('wallet.menu.claim_coins', en: 'Reward Coins', zh: '奖励金币');


  String get walletHistoryEmpty => _remoteText(
    'wallet.history.empty',
    en: 'There are no records yet.',
    zh: '暂无记录',
  );

  String get walletSpent =>
      _remoteText('consumption_history.tab.spent', en: 'Spent', zh: '已使用');

  String get walletExpired =>
      _remoteText('consumption_history.tab.expired', en: 'Expired', zh: '已过期');

  String get walletCheckIn =>
      _remoteText('wallet.button.top_up', en: 'Check in', zh: '签到');

  String get walletCoinsUnit =>
      resolveRemoteText(RemoteTexts.appCommonUnitCoin);

  // ── 消费记录 Consumption History ─────────────────────────────────────────────
  String get consumptionHistoryTitle => _remoteText(
    'consumption_history.title',
    en: 'Consumption History',
    zh: '消费记录',
  );

  String get consumptionHistorySpent =>
      _remoteText('consumption_history.tab.spent', en: 'Spent', zh: '已使用');

  String get consumptionHistoryExpired =>
      _remoteText('consumption_history.tab.expired', en: 'Expired', zh: '已过期');

  String consumptionHistoryEpisodeIndex(int index) => resolveRemoteText(
    RemoteTexts.consumptionHistoryEpisodeIndex,
    args: {'index': index},
  );

  String get consumptionHistoryCoins =>
      resolveRemoteText(RemoteTexts.consumptionHistoryCoins);

  // ── 交易记录 Transaction History ─────────────────────────────────────────────
  String get transactionHistoryTitle =>
      resolveRemoteText(RemoteTexts.transactionHistoryTitle);

  String get transactionHistoryMembership => _remoteText(
    'transaction_history.type.membership',
    en: 'Membership',
    zh: '会员',
  );

  String get transactionHistoryCoins =>
      _remoteText('transaction_history.type.coins', en: 'Coins', zh: '金币');

  String get transactionHistoryWeekly =>
      _remoteText('transaction_history.period.weekly', en: 'Weekly', zh: '周');

  String get transactionHistoryMonthly =>
      _remoteText('transaction_history.period.monthly', en: 'Monthly', zh: '月');

  String get transactionHistoryQuarterly => _remoteText(
    'transaction_history.period.quarterly',
    en: 'Quarterly',
    zh: '季',
  );

  String get transactionHistoryYearly =>
      _remoteText('transaction_history.period.yearly', en: 'Yearly', zh: '年');

  // ── 金币记录 Transaction History ─────────────────────────────────────────────
  String get recordCoinsTitle =>
      _remoteText('wallet.balance.bonus_coins', en: 'Reward Coins', zh: '奖励金币');

  // ── 商店 Store ─────────────────────────────────────────────
  String get storeTitle =>
      _remoteText('store_page.title.store', en: 'Store', zh: '商店');

  String get storeRestore =>
      _remoteText('wallet.menu.transaction_history', en: 'Restore', zh: '恢复购买');

  String get storeTips =>
      _remoteText('recharge_modal.tips.title', en: 'Tips', zh: '充值说明');

  String get storeBuyNow =>
      _remoteText('payment_modal.button.buy_now', en: 'Buy now', zh: '立即购买');

  String get storeSelected =>
      _remoteText('recharge_modal.vip.member', en: 'Selected', zh: '已选择');

  String get storeConfirmPurchase => _remoteText(
    'payment_modal.order.details',
    en: 'Confirm purchase',
    zh: '确认购买',
  );

  String get storeConfirm =>
      _remoteText('delete_account.confirm.confirm', en: 'Confirm', zh: '确认');

  String get storeCancel =>
      _remoteText('common.action.retry', en: 'Cancel', zh: '取消');

  String get storeClose =>
      _remoteText('payment_modal.button.done', en: 'Done', zh: '完成');

  String get storePurchaseProcessing => _remoteText(
    'payment.status.confirming',
    en: 'Confirming payment',
    zh: '确认支付中',
  );

  String get storePurchaseSuccess => _remoteText(
    'app.payment.status.success',
    en: 'Payment successful',
    zh: '支付成功',
  );

  String get storePurchaseFailed => _remoteText(
    'app.payment.status.failed_retry',
    en: 'Payment failed. Please try again.',
    zh: '支付失败，请重试',
  );

  String get storePurchaseCancelled => _remoteText(
    'app.payment.status.canceled',
    en: 'Payment canceled',
    zh: '支付已取消',
  );

  String get storePaymentNote => _remoteText(
    'payment_modal.title.payment_method',
    en: 'Payment will be handled by the app store.',
    zh: '将通过应用商店完成支付',
  );

  // ── 会员 Membership ─────────────────────────────────────────────
  String get membershipTitle => _remoteText(
    'membership_page.title.join',
    en: 'Join Membership',
    zh: '开通会员',
  );

  String get membershipBenefits => _remoteText(
    'membership_page.section.benefits',
    en: 'VIP Benefits',
    zh: '会员权益',
  );

  String get membershipBuyNow => _remoteText(
    'membership_page.button.join_now',
    en: 'Join Now',
    zh: '立即开通',
  );

  String get membershipWeekly =>
      _remoteText('membership_page.plan.weekly', en: 'Weekly VIP', zh: '周会员');

  String get membershipMonthly =>
      _remoteText('membership_page.plan.monthly', en: 'Monthly VIP', zh: '月会员');

  String get membershipQuarterly => _remoteText(
    'membership_page.plan.quarterly',
    en: 'Quarterly VIP',
    zh: '季会员',
  );

  String get membershipYearly =>
      _remoteText('membership_page.plan.yearly', en: 'Yearly VIP', zh: '年会员');

  String get membershipDay =>
      _remoteText('membership_page.unit.day', en: 'Day', zh: '日');

  String membershipPlanTitle({
    String? periodIso,
    String? fallbackId,
    String? fallbackTitle,
  }) {
    return switch (_membershipPeriodKind(
      periodIso,
      fallbackId,
      fallbackTitle,
    )) {
      _MembershipPeriodKind.weekly => membershipWeekly,
      _MembershipPeriodKind.monthly => membershipMonthly,
      _MembershipPeriodKind.quarterly => membershipQuarterly,
      _MembershipPeriodKind.yearly => membershipYearly,
      null => fallbackTitle ?? fallbackId ?? '',
    };
  }

  String get membershipUserUpgradedCount => _remoteText(
    'membership_page.user.upgraded_count',
    en: '10M+ users upgraded',
    zh: '1000万+ 用户已升级',
  );

  String get membershipPayment => _remoteText(
    'payment_modal.title.payment_method',
    en: 'Payment method',
    zh: '支付方式',
  );

  // ── 会员权益 Benefits ─────────────────────────────────────────────
  String get benefitSeriesTitle => _remoteText(
    'membership_page.benefit.free_dramas',
    en: 'Watch 8000+ dramas for free',
    zh: '8000+部剧集免费看',
  );

  String get benefitSeriesHighlight => _remoteText(
    'membership_page.benefit.weekly_new',
    en: '50+ new dramas added every week',
    zh: '每周稳定上新50+部新剧',
  );

  String get benefitSeriesDescription => _remoteText(
    'membership_page.benefit.daily_points',
    en: 'Daily VIP Points',
    zh: '每日会员积分',
  );

  String get benefitDownload =>
      _remoteText('membership_page.benefit.download', en: 'Download', zh: '下载');

  String get benefitMembersOnly => _remoteText(
    'membership_page.benefit.exclusive_dramas',
    en: 'VIP-exclusive Dramas',
    zh: '会员专享剧',
  );

  String get benefitHd => _remoteText(
    'membership_page.benefit.hd',
    en: '1080p Quality',
    zh: '1080p画质',
  );

  String get benefitNoAds =>
      _remoteText('membership_page.benefit.no_ads', en: 'Ad-free', zh: '免广告');

  // ── 会员提示 Tips ─────────────────────────────────────────────

  String get membershipTips =>
      _remoteText('membership_page.tips.title', en: 'Tips', zh: '提示');

  /// "Auto-renews. Cancel anytime."
  String get membershipAutoRenewCancel => _remoteText(
    'app.common.membership.auto_renew_cancel',
    en: 'Auto-renews. Cancel anytime.',
    zh: '自动续费 · 可随时取消',
  );

  /// 完整的订阅提示条款（JSON 字段 app.common.membership.payment_note）
  /// 内容包含带编号的条目，以 \n 分隔。
  String get membershipPaymentNote => _remoteText(
    'app.common.membership.payment_note',
    en: '1.DramaBox features both free and paid content for everyone.\n2. Paid content can be unlocked using coins or by subscribing to a membership. Membership-only content can only be accessed after subscribing to a membership.\n3. Coins will be used first when unlocking episodes. If the amount is insufficient, reward coins will automatically be used.\n4. During the subscription period, you will have unlimited access to all the series on DramaBox.\n5. Your App Store account will be automatically charged and your subscription will be renewed within 24 hours before the end of the current subscription period.\n6. To cancel the subscription, please go to your App Store account management and cancel at least 24 hours before the end of the current subscription period.\n7. If a top-up payment has been made successfully but your balance is not updated, please try clicking "Restore" to refresh your balance.\n8. If you have any other questions, please reach out to our online customer service via "Profile" - "Help & feedback".\n9. Coins and ongoing memberships are non-refundable and non-exchangeable once they are used.',
    zh: '1. DramaBox 提供免费和付费内容。\n2. 付费内容可使用金币或订阅会员解锁。会员专属内容仅在订阅后方可访问。\n3. 解锁剧集时优先使用金币，余额不足时自动使用奖励金币。\n4. 订阅期间，您可以无限访问 DramaBox 上的所有系列。\n5. 您的 App Store 账户将在当前订阅期结束前 24 小时内自动扣费并续订。\n6. 如需取消订阅，请在当前订阅期结束前至少 24 小时前往 App Store 账户管理取消。\n7. 如果充值成功但余额未更新，请尝试点击"恢复"刷新余额。\n8. 如有其他问题，请通过"个人资料"-"帮助与反馈"联系在线客服。\n9. 金币和正在进行的会员订阅一经使用，不可退款或兑换。',
  );

  // ── 充值 Recharge ─────────────────────────────────────────────
  String get rechargeTitle =>
      _remoteText('wallet.button.top_up', en: 'Top Up', zh: '充值');

  String get rechargeTips =>
      _remoteText('recharge_modal.tips.title', en: 'Tips', zh: '提示');

  String get rechargeBonus =>
      _remoteText('recharge_modal.product.bonus', en: 'Bonus', zh: '赠送');

  String get rechargeVipWeek =>
      _remoteText('recharge_modal.vip.week', en: 'Weekly', zh: '周');

  String get rechargeVipMonth =>
      _remoteText('recharge_modal.vip.month', en: 'Monthly', zh: '月');

  String get rechargeVipQuarter =>
      _remoteText('recharge_modal.vip.quarter', en: 'Quarterly', zh: '季');

  String get rechargeVipYear =>
      _remoteText('recharge_modal.vip.year', en: 'Yearly', zh: '年');

  String get rechargeVipMember =>
      _remoteText('recharge_modal.vip.member', en: 'VIP', zh: '会员');

  String rechargeMembershipTitle({
    String? periodIso,
    String? fallbackId,
    String? fallbackTitle,
  }) {
    final period = switch (_membershipPeriodKind(
      periodIso,
      fallbackId,
      fallbackTitle,
    )) {
      _MembershipPeriodKind.weekly => rechargeVipWeek,
      _MembershipPeriodKind.monthly => rechargeVipMonth,
      _MembershipPeriodKind.quarterly => rechargeVipQuarter,
      _MembershipPeriodKind.yearly => rechargeVipYear,
      null => null,
    };
    if (period == null) {
      return fallbackTitle ?? fallbackId ?? rechargeVipMember;
    }
    if (locale.languageCode == 'zh') {
      return '$period$rechargeVipMember';
    }
    return '$period $rechargeVipMember';
  }

  String get rechargeBenefitDailyPoints => _remoteText(
    'recharge_modal.benefit.daily_points',
    en: 'Daily member points',
    zh: '每日会员积分',
  );

  String get rechargeBenefitDownload =>
      _remoteText('recharge_modal.benefit.download', en: 'Download', zh: '下载');

  String get rechargeBenefitHd => _remoteText(
    'recharge_modal.benefit.hd',
    en: '1080p Quality',
    zh: '1080p 高清',
  );

  String get rechargeBenefitUnlockDramas => _remoteText(
    'recharge_modal.benefit.unlock_dramas',
    en: 'Unlock access to N+ series',
    zh: '解锁 N+ 系列',
  );

  // ── 播放器 Player ─────────────────────────────────────────────
  String get playerEpisodes =>
      _remoteText('player.action.episodes', en: 'Episodes', zh: '选集');

  String get playerShare =>
      _remoteText('player.action.share', en: 'Share', zh: '分享');

  String get playerMore =>
      _remoteText('player.synopsis.more', en: 'More', zh: '更多');
  String get playerLess =>
      _remoteText('player.synopsis.less', en: 'Less', zh: '收起');

  String get playerDownload =>
      _remoteText('player.action.share', en: 'Download', zh: '下载');

  String  playerEpisode(String text) =>
      _replaceWords(
          removeWord: 'X',
          word: text,
          originWord: _remoteText('player.header.episode_index', en: 'Episode X', zh: '第X集'));

  String get playerWatchNow =>
      _remoteText('player.unlock.cta', en: 'Watch Now', zh: '立即观看');

  String get playerSpeed =>
      _remoteText('player.header.speed', en: 'Speed', zh: '倍速');


  String get playerMoreLikeThis => _remoteText(
    'episode_modal.recommend.more_like_this',
    en: 'More Like This',
    zh: '猜你喜欢',
  );

  String get playerUnlockNow =>
      _remoteText('player.unlock.cta', en: 'Unlock Now', zh: '立即解锁');

  String get playerMemberUnlock => _remoteText(
    'player.unlock.member_unlock',
    en: 'Member unlock',
    zh: '会员解锁',
  );

  String get playerBecomeMember =>
      _remoteText('profile.button.join', en: 'Become a member >', zh: '开通会员 >');

  String get playerPlay =>
      _remoteText('unlock_modal.button.play_episode', en: 'Play', zh: '播放');



  String get playerPrice =>
      _remoteText('player.unlock.price', en: 'Price:', zh: '价格:');

  String get playerBalance =>
      _remoteText('app.common.label.balance', en: 'Balance:', zh: '余额:');

  String get playerRechargeUnlockTitle =>
      _remoteText('wallet.button.top_up', en: 'Recharge to unlock', zh: '充值解锁');

  String get playerRequiredCoins =>
      _remoteText('app.common.unit.coin', en: 'Required', zh: '所需金币');


  String get playerCoinPackages =>
      _remoteText('payment_modal.button.buy_now', en: 'Coins', zh: '金币充值');

  String get playerMembershipPackages =>
      _remoteText('recharge_modal.vip.member', en: 'VIP', zh: '会员');

  String get playerBonus =>
      _remoteText('recharge_modal.product.bonus', en: 'Bonus', zh: '赠送');

  String get playerLimitedOffer => _remoteText(
    'recharge_modal.product.bonus',
    en: 'Limited offer',
    zh: '限时优惠',
  );

  String get playerAutoRenewCancel => _remoteText(
    'app.common.membership.auto_renew_cancel',
    en: 'Auto renew · Cancel anytime',
    zh: '自动续费 · 可随时取消',
  );

  // String get playerUnlockProcessing => _remoteText(
  //   'payment.status.confirming',
  //   en: 'Processing purchase...',
  //   zh: '正在处理购买...',
  // );

  String get playerUnlockFailed => _remoteText(
    'payment.status.failed_retry',
    en: 'Purchase failed. Please try again.',
    zh: '购买失败，请重试。',
  );

  String get playerUnlockSuccessful => _remoteText(
    'payment.status.success',
    en: 'Unlock successful',
    zh: '解锁成功',
  );

  String get playerUnlockedAutomatically => _remoteText(
    'player.unlock.cta',
    en: 'Unlocked automatically',
    zh: '已自动解锁',
  );

  String get playerMembershipActivated => _remoteText(
    'payment.status.success',
    en: 'Membership activated',
    zh: '会员已开通',
  );

  String get playerNoEpisodes => _remoteText(
    'player.episodes.unavailable',
    en: 'No episodes available yet.',
    zh: '暂无可播放剧集',
  );

  String get playerFeedLoadFailed => _remoteText(
    'player.state.playback_failed',
    en: 'Player failed to load.',
    zh: '播放失败，请重试',
  );

  String get playerEpisodeUnavailable => _remoteText(
    'player.state.episode_unavailable',
    en: 'This episode is unavailable.',
    zh: '本集暂不可播放',
  );

  String get playerVideoLoading => _remoteText(
    'player.state.video_loading',
    en: 'Loading video',
    zh: '视频加载中',
  );

  String get playerSubtitleFailed => _remoteText(
    'player.state.subtitle_failed',
    en: 'Failed to load subtitles',
    zh: '字幕加载失败',
  );

  String get playerFacebook =>
      _remoteText('player.facebook', en: 'Facebook', zh: 'Facebook');

  String get playerWhatsApp =>
      _remoteText('player.whatsapp', en: 'WhatsApp', zh: 'WhatsApp');

  String get playerMessenger =>
      _remoteText('player.messenger', en: 'Messenger', zh: 'Messenger');

  String get playerInstagram =>
      _remoteText('player.instagram', en: 'Instagram', zh: 'Instagram');

  String get playerSnapchat =>
      _remoteText('player.snapchat', en: 'Snapchat', zh: 'Snapchat');

  // ── 分享 Share ─────────────────────────────────────────────
  String get shareTitle =>
      _remoteText('share_modal.title.share', en: 'Share', zh: '分享');

  // ── 剧集弹窗 Episode Modal ─────────────────────────────────────────────
  String get playerSynopsis =>
      _remoteText('episode_modal.tab.synopsis', en: 'Synopsis', zh: '简介');

  String get episodeModalEpisodes =>
      _remoteText('episode_modal.tab.episodes', en: 'Episodes', zh: '剧集');

  String get episodeModalMore =>
      _remoteText('episode_modal.synopsis.more', en: 'More', zh: '更多');

  String get episodeModalViews =>
      _remoteText('episode_modal.info.views', en: 'Views', zh: '播放量');

  String get episodeModalRecommendMoreLikeThis => _remoteText(
    'episode_modal.recommend.more_like_this',
    en: 'More Like This',
    zh: '猜你喜欢',
  );

  // ── 首页分类 Category ─────────────────────────────────────────────
  String get categoryEmpty => _remoteText(
    'home.empty.category_no_content',
    en: 'No content yet',
    zh: '暂无内容',
  );

  String get categoryFeatured =>
      _remoteText('featured', en: 'Selected', zh: '精选');

  String get categoryHot => _remoteText('hot', en: 'Hot', zh: '热门');

  String get categoryCartoon => _remoteText('cartoon', en: 'Cartoon', zh: '动漫');

  // ── 通用单位 Units ─────────────────────────────────────────────
  String get unitDay => _remoteText('app.common.unit.day', en: 'Days', zh: '天');

  String get unitEpisode =>
      _remoteText('app.common.unit.episode', en: 'Episode', zh: '集');

  String get unitExpires =>
      _remoteText('app.common.unit.expires', en: 'Expires', zh: '过期');

  String get unitTime =>
      _remoteText('app.common.unit.time', en: 'Times', zh: '次');

  String get unitView =>
      _remoteText('app.common.unit.view', en: 'Views', zh: '播放量');

  String get unitBonusCoin =>
      _remoteText('app.common.unit.bonus_coin', en: 'Bonus Coins', zh: '赠送金币');

  String get unitCoin =>
      _remoteText('app.common.unit.coin', en: 'Coins', zh: '金币');

  // ── 奖励金币 Claim Coins ─────────────────────────────────────────────

  String get claimCoinsName =>
      _remoteText('claim_coins.reward.name', en: 'Reward Coins', zh: '奖励金币');

  String get claimCoinsTypeRechargeBonus =>
      _remoteText('claim_coins.type.recharge_bonus', en: 'Recharge', zh: '充值');

  // ── 网络错误 Network ─────────────────────────────────────────────
  String get networkError => _remoteText(
    'app.common.error.network_retry',
    en: 'Network error. Please try again later.',
    zh: '网络错误，请稍后重试。',
  );

  // ── 占位符（开发用）─────────────────────────────────────────────
  String get memberPagePlaceholder => _remoteText(
    'membership_page.title.join',
    en: 'Under development',
    zh: '正在开发中',
  );

  String get profileSettingsPlaceholder => _remoteText(
    'settings.title',
    en: 'Settings will be available later',
    zh: '设置页将在后续阶段开放',
  );

  String get settingsLegalPlaceholder => _remoteText(
    'settings.title',
    en: 'The full document will be available later',
    zh: '完整文档将在后续阶段提供',
  );

  String get storeRestoreUnavailable => _remoteText(
    'wallet.menu.transaction_history',
    en: 'Restore is unavailable right now',
    zh: '暂不支持恢复购买',
  );

  String get authDeleteAccountMessage => _remoteText(
    'delete_account.confirm.message',
    en: 'This is a mock delete account confirmation',
    zh: '当前为模拟确认',
  );

  String get accountCancellationDeleteButtonCountdown => _remoteText(
    'delete_account.button.confirm_deletion',
    en: 'Delete account',
    zh: '删除账号',
  );

  _MembershipPeriodKind? _membershipPeriodKind(
    String? periodIso,
    String? fallbackId,
    String? fallbackTitle,
  ) {
    final iso = periodIso?.toUpperCase();
    if (iso == 'P1W') return _MembershipPeriodKind.weekly;
    if (iso == 'P1M') return _MembershipPeriodKind.monthly;
    if (iso == 'P3M') return _MembershipPeriodKind.quarterly;
    if (iso == 'P1Y') return _MembershipPeriodKind.yearly;

    final normalized = '${fallbackId ?? ''} ${fallbackTitle ?? ''}'
        .toLowerCase();
    if (normalized.contains('quarter') || normalized.contains('season')) {
      return _MembershipPeriodKind.quarterly;
    }
    if (normalized.contains('year') || normalized.contains('annual')) {
      return _MembershipPeriodKind.yearly;
    }
    if (normalized.contains('month')) {
      return _MembershipPeriodKind.monthly;
    }
    if (normalized.contains('week')) {
      return _MembershipPeriodKind.weekly;
    }
    return null;
  }
}

enum _MembershipPeriodKind { weekly, monthly, quarterly, yearly }

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
