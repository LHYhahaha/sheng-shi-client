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

  /// 离线可用的内置 Locale。运行时可用语言由
  /// [runtimeSupportedLocalesProvider] 根据服务端下发 code 扩展。
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
  static final Map<String, Map<String, dynamic>> _remoteStringsByLanguage =
      <String, Map<String, dynamic>>{};

  /// 设置远程语言包。
  ///
  /// 由 I18nController 在语言包加载成功后调用。
  static void setRemoteStrings(
    Map<String, dynamic>? strings, {
    String languageCode = 'en',
    bool isActiveLanguage = true,
  }) {
    if (strings == null) {
      _remoteStringsByLanguage.remove(languageCode);
    } else {
      _remoteStringsByLanguage[languageCode] = strings;
    }
    if (!isActiveLanguage) {
      return;
    }
    _remoteStrings = strings;
  }

  /// 获取远程语言包。
  static Map<String, dynamic>? get remoteStrings => _remoteStrings;

  static void clearRemoteStrings() {
    _remoteStrings = null;
    _remoteStringsByLanguage.clear();
  }

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

  /// 动态配置文案：当前语言 → 默认英语语言包 → 客户端原 Tab 文案。
  String resolveDynamicTabText(String key, {required String fallback}) {
    final current = _readRemoteString(_remoteStrings, key);
    if (current != null) {
      return current;
    }
    final defaultLanguage = _readRemoteString(
      _remoteStringsByLanguage['en'],
      key,
    );
    return defaultLanguage ?? fallback;
  }

  static String? _readRemoteString(Map<String, dynamic>? strings, String key) {
    final value = strings?[key];
    return value is String && value.isNotEmpty
        ? value.replaceAll(r'\n', '\n')
        : null;
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

  String _replaceWords({
    required String removeWord,
    required String word,
    required String originWord,
  }) {
    String text = "";
    if (originWord.contains(removeWord)) {
      text = originWord.replaceAll(removeWord, word);
      return text;
    }
    return originWord;
  }

  // ── 通用 ─────────────────────────────────────────────
  String get appTitle =>
      _remoteText('appTitle', en: 'NovaShort', zh: 'NovaShort');

  String vipPlanIntroPrice({
    required String sale,
    required String price,
    required String num,
    required String ordinal,
    required String unit,
  }) => resolveRemoteText(
    RemoteTexts.vipPlanIntroPrice,
    args: {
      'sale': sale,
      'price': price,
      'num': num,
      'ordinal': ordinal,
      'unit': unit,
    },
  );

  String get retry => _remoteText('common.action.retry', en: 'Retry', zh: '重试');

  String get claim => _remoteText('common.action.claim', en: 'Claim', zh: '领取');

  String get goComplete =>
      _remoteText('common.action.go_complete', en: 'Go', zh: '去完成');

  String get ok => _remoteText('common.action.ok', en: 'OK', zh: '好的');

  String get claimed =>
      _remoteText('common.status.claimed', en: 'Claimed', zh: '已领取');

  String get loading =>
      _remoteText('common.status.loading', en: 'Loading', zh: '加载中');

  String get noData =>
      _remoteText('common.status.no_data', en: 'No data', zh: '暂无数据');

  String get emptyNoDramas =>
      _remoteText('home.empty.no_dramas', en: 'No dramas yet', zh: '暂无短剧');

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

  String get myListSelectAll =>
      _remoteText('my_list.action.select_all', en: 'Select all', zh: '全选');

  String get myListDeselectAll => _remoteText(
    'my_list.action.deselect_all',
    en: 'Deselect all',
    zh: '取消全选',
  );

  String get myListDelete =>
      _remoteText('my_list.action.remove', en: 'Delete', zh: '删除');

  String myListEpisode(String text) => _replaceWords(
    removeWord: 'X',
    word: text,
    originWord: _remoteText('my_list.episode_index', en: 'EP.X', zh: '第X集'),
  );

  String myListEpisode2(String text) => _replaceWords(
    removeWord: 'X',
    word: text,
    originWord: _remoteText('my_list.episode_index2', en: 'EP.X', zh: 'X集'),
  );

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
    'my_list.taken.down',
    en: 'The short drama has been taken down',
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

  //—— 搜索页 search ————————————————————————————————————————————————

  String get searchKeyWordHint => _remoteText(
    'search.input.key.word',
    en: 'Enter search words',
    zh: '输入关键词',
  );

  String get searchHint =>
      _remoteText('search.input.hint', en: 'Search for a drama', zh: '搜索短剧');

  String get searchHistory =>
      _remoteText('search.history.title', en: 'Search History', zh: '搜索历史');

  String get searchHistoryCancel =>
      _remoteText('search.history.cancel', en: 'Cancel', zh: '取消');

  String get searchHistoryClearAll =>
      _remoteText('search.history.clear_all', en: 'Clear all', zh: '全部清除');

  String get searchHistoryClearConfirm => _remoteText(
    'search.history.clear_confirm',
    en: 'Clear all search history?',
    zh: '确认清空全部搜索历史？',
  );

  String get searchHistoryConfirm =>
      _remoteText('search.history.confirm', en: 'Confirm', zh: '确定');

  String get searchHot =>
      _remoteText('search.ranking.hot_searches', en: 'Top Searched', zh: '热搜榜');

  String get searchTrending =>
      _remoteText('search.ranking.hot_plays', en: 'Most Trending', zh: '热播榜');

  String get searchNewReleases =>
      _remoteText('search.ranking.new_online', en: 'New Releases', zh: '上新榜');

  String get searchRankEmpty => _remoteText(
    "search.rank.empty",
    en: "There is no content for now",
    zh: "暂无内容",
  );

  // ── 个人中心 Profile ─────────────────────────────────────────────
  String get profileLogin =>
      _remoteText('profile.user.login', en: 'Log in', zh: '登录');

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

  String get profileHistory =>
      _remoteText('profile.menu.history', en: 'History', zh: '历史');

  String get profileReward => _remoteText(
    'profile.menu.reward_center',
    en: 'Rewards Center',
    zh: '福利中心',
  );

  String get languagePageTitle =>
      _remoteText('language_page.title.language', en: 'Language', zh: '语言');

  String get languagePageButton =>
      _remoteText('language_page.button.done', en: 'Done', zh: '完成');

  String get profileMember =>
      _remoteText('profile.user.member', en: 'Member', zh: '会员');

  String get profileRenewal =>
      _remoteText('membership_page.plan.monthly', en: 'Renewal', zh: '续费');

  String get profileFeedback => _remoteText(
    'profile.menu.help_feedback',
    en: 'Help & Feedback',
    zh: '问题与帮助',
  );

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
    'login.button.google',
    en: 'Sign in with Google',
    zh: 'Google登录',
  );

  String get authFacebookLogin => _remoteText(
    'login.button.facebook',
    en: 'Sign in with Facebook',
    zh: 'Facebook登录',
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

  String get membershipUpgraded => _remoteText(
    'membership_page.upgraded',
    en: '10M+ users upgraded',
    zh: '1000 万+ 用户已升级',
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

  // ── 会员中心 Member Center ─────────────────────────────────────
  String get memberCenterRedeemPoints => _remoteText(
    'member_center.section.exchange',
    en: 'Redeem Points',
    zh: '积分兑换',
  );

  String get memberCenterExchangeSuccess => _remoteText(
    'member_center.toast.exchange_success',
    en: 'Redeemed successfully',
    zh: '兑换成功',
  );

  String get memberCenterToastExchangeMembersOnly => _remoteText(
    'member_center.toast.exchange_members_only',
    en: 'Only members can redeem.',
    zh: '仅会员可兑换',
  );

  String get memberCenterButtonExchange =>
      _remoteText('member_center.button.exchange', en: 'Redeem', zh: '兑换');

  String get memberCenterSectionVipDramas => _remoteText(
    'member_center.section.vip_dramas',
    en: 'VIP-exclusive Dramas',
    zh: '会员专享剧',
  );

  String memberCenterExchangeDaysMember(int days) => _remoteText(
    'member_center.modal.exchange.days_member',
    en: '{days}-Day Membership',
    zh: '{days}日会员',
  ).replaceAll('{days}', days.toString());

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

  // ── 广告 ad ─────────────────────────────────────────────

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
      return period;
    }
    return period;
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

  String get playerCollapse =>
      _remoteText('player.synopsis.collapse', en: 'Collapse', zh: '收起');

  String get playerDownload =>
      _remoteText('player.action.share', en: 'Download', zh: '下载');

  String playerEpisode(String text) => _replaceWords(
    removeWord: 'X',
    word: text,
    originWord: _remoteText(
      'player.header.episode_index',
      en: 'Episode X',
      zh: '第X集',
    ),
  );

  String get playerWatchNow => _remoteText('', en: 'Watch Now', zh: '立即观看');

  String get playerSpeed =>
      _remoteText('player.header.speed', en: 'Speed', zh: '倍速');

  String get playerMoreLikeThis => _remoteText(
    'episode_modal.recommend.more_like_this',
    en: 'More Like This',
    zh: '猜你喜欢',
  );

  String get playerUnlockNow =>
      _remoteText('player.unlock.cta', en: 'Unlock Now', zh: '立即解锁');

  String get playerUnlockWatchAd => _remoteText(
    'player.unlock.watch_ad',
    en: 'Watch Ads to unlock for free',
    zh: '看广告免费解锁',
  );

  String get playerUnlockReplay =>
      _remoteText('player.unlock.replay', en: 'Replay', zh: '重新播放');

  String get playerAdLimitRegular => _remoteText(
    'player.ad_limit.regular',
    en: 'Regular drama ad limit reached.',
    zh: '今日广告解锁普通短剧已上限',
  );

  String get playerAdLimitVip => _remoteText(
    'player.ad_limit.vip',
    en: 'VIP drama ad limit reached.',
    zh: '今日广告解锁会员短剧已上限',
  );

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

  String get paywallVipTitle =>
      _remoteText('paywall.vip.title', en: 'Watch VIP Content', zh: '观看会员内容');

  String get paywallJumpTitle =>
      _remoteText('paywall.jump.title', en: 'Unlock Episode', zh: '解锁剧集');

  String get paywallJumpDescription => _remoteText(
    'paywall.jump.desc',
    en: 'Join VIP to unlock all. Coins unlock episodes in order.',
    zh: '开通会员解锁全集，金币仅可按顺序解锁',
  );

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

  String get rewardsRuleEntry =>
      _remoteText('rewards.rule.entry', en: 'Rules', zh: '规则');

  String get rewardsRuleTitle =>
      _remoteText('rewards.rule.title', en: 'Reward Rules', zh: '奖励规则');

  String rewardsSigninDayIndex(int day) => _remoteText(
    'rewards.signin.day_index',
    en: 'Day {day}',
    zh: '第{day}天',
  ).replaceAll('{day}', day.toString());

  String get rewardsTaskLogin => _remoteText(
    'rewards.task.login',
    en: 'Sign in with any account',
    zh: '登录任意账号',
  );

  String get rewardsTaskShare => _remoteText(
    'rewards.task.share',
    en: 'Share a drama with friends',
    zh: '分享短剧给好友',
  );

  String get rewardsTaskWatch5 => _remoteText(
    'rewards.task.watch_5',
    en: 'Watch dramas for 5 minutes',
    zh: '播放短剧5分钟',
  );

  String get rewardsTaskWatch10 => _remoteText(
    'rewards.task.watch_10',
    en: 'Watch dramas for 10 minutes',
    zh: '播放短剧10分钟',
  );

  String get rewardsTaskWatch15 => _remoteText(
    'rewards.task.watch_15',
    en: 'Watch dramas for 15 minutes',
    zh: '播放短剧15分钟',
  );

  String get rewardsTaskEnablePush => _remoteText(
    'rewards.task.enable_push',
    en: 'Enable push notifications',
    zh: '打开系统推送',
  );

  String get rewardsRuleContent => _remoteText(
    'rewards.rule.content',
    en: '1. The final interpretation of this campaign belongs to {appname}.\n2. Each user can check in only once per day.\n3. If check-in progress is interrupted because the user is not signed in, the progress will reset to Day 1.\n4. Rewards can usually be used to unlock episodes. You can view historical records in your wallet.\n5. Coins will be used first when unlocking episodes. If the balance is insufficient, reward coins will be used automatically.\n6. Reward coins are valid for 30 days.\n7. All tasks and check-ins refresh at 00:00 India Standard Time.',
    zh: '1. 活动最终解释权属于{appname}。\n2. 用户每日只可签到一次。\n3. 如果用户因为未登录导致签到中断，签到进度将被重置回第一天。\n4. 奖励会常见可用来解锁剧集，您可以在钱包中查看历史记录。\n5. 金币在解锁剧集时会优先被使用，如果金额不够将会自动使用奖励金币。\n6. 奖励金币为 30 天有效期限。\n7. 所有任务和签到会在印度时区 0 点刷新。',
  ).replaceAll('{appname}', appTitle);

  String get claimCoinsName =>
      _remoteText('claim_coins.reward.name', en: 'Reward Coins', zh: '奖励金币');

  String get claimCoinsTypeRechargeBonus =>
      _remoteText('claim_coins.type.recharge_bonus', en: 'Recharge', zh: '充值');

  String get claimCoinsTypeSigninBonus => _remoteText(
    'claim_coins.type.signin_bonus',
    en: 'Check-in Bonus',
    zh: '签到赠送',
  );

  String get claimCoinsTypeTaskBonus =>
      _remoteText('claim_coins.type.task_bonus', en: 'Task Bonus', zh: '任务赠送');

  String get claimCoinsTypeAdminBonus => _remoteText(
    'claim_coins.type.admin_bonus',
    en: 'Admin Credit',
    zh: '后台补发',
  );

  // ── 会员积分 Member Points ─────────────────────────────────────
  String get memberPointsTitle =>
      _remoteText('member_points.title', en: 'VIP Points', zh: '会员积分');

  String get memberPointsLockedDailyReward => _remoteText(
    'member_points.status.locked_daily_reward',
    en: 'Subscribe to unlock daily rewards',
    zh: '订阅即可解锁每日奖励',
  );

  String get memberPointsDailyRewardTitle => _remoteText(
    'member_points.daily_reward.title',
    en: 'Daily Rewards',
    zh: '每日奖励',
  );

  String get memberPointsDailyPoints =>
      _remoteText('member_points.daily_points', en: 'Daily Points', zh: '每日积分');

  String get memberPointsFreeMembership => _remoteText(
    'member_points.free_membership',
    en: 'Free Membership',
    zh: '免费会员',
  );

  String get memberPointsPaidMemberOnly => _remoteText(
    'member_points.paid_member_only',
    en: 'Only paid members can earn points',
    zh: '仅付费会员可享有积分',
  );

  String memberPointsMemberDayCount(int day) => _remoteText(
    'member_points.member_day_count',
    en: 'Today is Day {day} of your membership',
    zh: '今天是会员第{day}天',
  ).replaceAll('{day}', day.toString());

  String get memberPointsDailyLottery => _remoteText(
    'member_points.daily_lottery',
    en: 'Daily Lottery',
    zh: '每日抽奖',
  );

  String get memberPointsPlayReward =>
      _remoteText('member_points.play_reward', en: 'Watch Reward', zh: '播放奖励');

  String get memberPointsWatchOver30Min => _remoteText(
    'member_points.watch_over_30min',
    en: '(＞ 30 min)',
    zh: '(＞ 30 分钟)',
  );

  String get memberPointsWatchRequired => _remoteText(
    'member_points.toast.watch_required',
    en: 'Watch dramas for 30 minutes',
    zh: '需观看短剧30分钟',
  );

  String get memberPointsRuleTitle =>
      _remoteText('member_points.rule.title', en: 'Points Rules', zh: '积分规则');

  String get memberPointsRuleContent => _remoteText(
    'member_points.rule.content',
    en: '1. The final interpretation of this campaign belongs to {appname}.\n2. Paid members of {appname} can claim a random amount of member points once per day. Only paid members can claim points; non-members and free members cannot claim points.\n3. Member points can only be used to redeem items in the points store.\n4. You can view point changes in Points Details.\n5. Member point benefits refresh every day at 00:00 India Standard Time.\n6. Tap Official Rules to view detailed instructions.',
    zh: '1.活动最终解释权属于{appname}。\n2.{appname}付费会员用户每日可领取1天随机数量的会员积分。仅付费会员可领取积分，非会员与免费会员无法领取积分\n3.会员积分只可用于在积分商城兑换商品\n4.你可以在积分明细中检视积分的变动\n5.会员积分福利将于每天当地时间早上6点刷新\n6.检视详细说明请点选官方规则',
  ).replaceAll('{appname}', appTitle);

  String get memberPointsRule =>
      _remoteText('member_points.rule.official', en: 'Rules', zh: '规则');

  String get memberPointsDetailTitle => _remoteText(
    'member_points.detail.title',
    en: 'Points History',
    zh: '积分明细',
  );

  String get memberPointsDetailEmpty =>
      _remoteText('member_points.detail.empty', en: 'No records', zh: '没有相关记录');

  String get memberPointsDetailTypeDaily => _remoteText(
    'member_points.detail.type.daily',
    en: 'Daily VIP Points',
    zh: '每日会员积分',
  );

  String get memberPointsDetailTypePush => _remoteText(
    'member_points.detail.type.push',
    en: 'Enable notifications',
    zh: '打开通知',
  );

  String get memberPointsDetailTypeWatch => _remoteText(
    'member_points.detail.type.watch',
    en: 'Watch Reward',
    zh: '播放奖励',
  );

  String memberPointsDetailTypeExchange(int days) => _remoteText(
    'member_points.detail.type.exchange',
    en: 'Redeem {days}-day VIP',
    zh: '兑换{days}日会员',
  ).replaceAll('{days}', days.toString());

  String get memberPointsSuccessTitle => _remoteText(
    'member_points.success.title',
    en: 'Claimed Successfully',
    zh: '领取成功',
  );

  // ── 1.0.2 远程文案补充（来自多语言翻译.xlsx）────────────────────────
  // ── 1.0.2 / 通用 ─────────────────────────────────────────────
  String get commonActionSubmit =>
      _remoteText('common.action.submit', en: 'Submit', zh: '提交');

  String get appAccountBannedDialogMessage => _remoteText(
    'app.account.banned.dialog.message',
    en: 'This account is temporarily unavailable.',
    zh: '该账户暂时无法使用',
  );

  String get appAccountBannedActionFeedback => _remoteText(
    'app.account.banned.action.feedback',
    en: 'Submit Feedback',
    zh: '提交反馈',
  );

  String get appAccountBannedActionExit =>
      _remoteText('app.account.banned.action.exit', en: 'Exit', zh: '退出');

  String get appRecommendPopupTitleNextDrama => _remoteText(
    'app.recommend_popup.title_next_drama',
    en: 'Your Next Drama',
    zh: '你的下一部短剧',
  );

  String get appRecommendPopupSubtitleNextDrama => _remoteText(
    'app.recommend_popup.subtitle_next_drama',
    en: 'A story you might love',
    zh: '你可能会喜欢的故事',
  );

  String get appRecommendPopupTitleMoreLikeThis => _remoteText(
    'app.recommend_popup.title_more_like_this',
    en: 'More Like This',
    zh: '更多相似短剧',
  );

  // ── 1.0.2 / 弹窗 ─────────────────────────────────────────────
  String get popupAutoRecommendButtonWatchNow => _remoteText(
    'popup.auto_recommend.button.watch_now',
    en: 'Watch Now',
    zh: '立即观看',
  );

  String get popupDramaExitTitle => _remoteText(
    'popup.drama_exit.title',
    en: 'More great dramas for you',
    zh: '为您推荐更多好剧',
  );

  String get popupDramaExitActionExit =>
      _remoteText('popup.drama_exit.action.exit', en: 'Exit', zh: '退出');

  String get popupDramaExitActionPlay =>
      _remoteText('popup.drama_exit.action.play', en: 'Play', zh: '播放');

  String get popupNextDramaSubtitle => _remoteText(
    'app.recommend_popup.subtitle_next_drama',
    en: 'A story you might love',
    zh: '你可能会喜欢的故事',
  );

  String get popupNextDramaTitle => _remoteText(
    'app.recommend_popup.title_next_drama',
    en: 'Your Next Drama',
    zh: '你的下一部短剧',
  );

  // ── 1.0.2 / 推荐Tab ─────────────────────────────────────────────
  String get recommendTabActionViewAllEpisodes => _remoteText(
    'recommend_tab.action.view_all_episodes',
    en: 'View All Episodes',
    zh: '观看全集',
  );

  String get recommendTabEmptyNoContent => _remoteText(
    'recommend_tab.empty.no_content',
    en: 'No recommendations yet',
    zh: '暂无可推荐内容',
  );

  // ── 1.0.2 / 我的收藏 ─────────────────────────────────────────────
  String get favoriteSectionHotRecommend => _remoteText(
    'favorite.section.hot_recommend',
    en: 'Hot Recommendations',
    zh: '热播推荐',
  );

  // ── 1.0.2 / 搜索页 ─────────────────────────────────────────────
  String get searchRankHotSearch =>
      _remoteText('search.rank.hot_search', en: 'Top Searched', zh: '热搜榜');

  String get searchRankHotDrama =>
      _remoteText('search.rank.hot_drama', en: 'Most Trending', zh: '热播榜');

  String get searchRankNewDrama =>
      _remoteText('search.rank.new_drama', en: 'New Releases', zh: '新剧榜');

  String get searchTabHottest =>
      _remoteText('search.tab.hottest', en: 'Hottest', zh: '最热');

  String get searchTabLatest =>
      _remoteText('search.tab.latest', en: 'Latest', zh: '最新');

  String get searchTabUnwatched =>
      _remoteText('search.tab.unwatched', en: 'Unwatched', zh: '未观看');

  String get searchEmptyNoResult => _remoteText(
    'search.empty.no_result',
    en: 'No results found',
    zh: '未找到相关内容',
  );

  String get searchRecommendGuessLike => _remoteText(
    'search.recommend.guess_like',
    en: 'You May Like',
    zh: '猜你喜欢',
  );

  // ── 1.0.2 / 支付弹窗 ─────────────────────────────────────────────
  String get paymentModalMethodApplePay => _remoteText(
    'payment_modal.method.apple_pay',
    en: 'Apple Pay',
    zh: '苹果订阅',
  );

  // ── 1.0.2 / 短剧播放页 ─────────────────────────────────────────────
  String get playerSubtitleEntry =>
      _remoteText('player.subtitle.entry', en: 'Subtitles', zh: '字幕');

  String get playerSubtitleOff =>
      _remoteText('player.subtitle.off', en: 'Off', zh: '关闭');

  // ── 1.0.2 / 分享弹窗 ─────────────────────────────────────────────
  String get shareActionCopyLink =>
      _remoteText('share.action.copy_link', en: 'Copy Link', zh: '复制链接');

  String get shareToastCopySuccess =>
      _remoteText('share.toast.copy_success', en: 'Copied', zh: '复制成功');

  String shareMessage({required String dramaTitle, required String shareUrl}) {
    return _remoteText(
          'share.message',
          en: 'I\'m watching {dramaTitle} on {appTitle}. It\'s amazing—come watch with me! {shareUrl}',
          zh: '我正在{appTitle}上看{dramaTitle}，很精彩，快来一起看吧！{shareUrl}',
        )
        .replaceAll('{appTitle}', appTitle)
        .replaceAll('{dramaTitle}', dramaTitle)
        .replaceAll('{shareUrl}', shareUrl);
  }

  // ── 1.0.2 / 分享落地页 ─────────────────────────────────────────────
  String get shareLandingButtonOpenApp =>
      _remoteText('share.landing.button.open_app', en: 'Open', zh: '开启');

  // ── 1.0.2 / 我的页面 ─────────────────────────────────────────────
  String get profileRewardPendingCoins => _remoteText(
    'profile.reward.pending_coins',
    en: 'Coins to claim',
    zh: '待领取金币',
  );

  // ── 1.0.2 / 会员中心 ─────────────────────────────────────────────
  String get memberCenterTitleMyMember => _remoteText(
    'member_center.title.my_member',
    en: 'My Membership',
    zh: '我的会员',
  );

  String get memberCenterSectionDailyReward => _remoteText(
    'member_center.section.daily_reward',
    en: 'Daily Rewards',
    zh: '每日奖励',
  );

  String get memberCenterSectionMyPrivileges => _remoteText(
    'member_center.section.my_privileges',
    en: 'My Privileges',
    zh: '我的特权',
  );

  String get memberCenterModalExchangeInsufficientPoints => _remoteText(
    'member_center.modal.exchange.insufficient_points',
    en: 'Insufficient points',
    zh: '积分不足',
  );

  String memberCenterModalExchangePointsCost(Object points) => _remoteText(
    'member_center.modal.exchange.points_cost',
    en: '{points} Member Points',
    zh: '{points} 会员积分',
  ).replaceAll('{points}', points.toString());

  String memberCenterModalExchangeRules(Object days) => _remoteText(
    'member_center.modal.exchange.rules',
    en: '1. After redemption, your current membership will be extended by {days} day(s).\n2. The redeemed membership duration will take effect after your store membership ends.\n3. Redeemed items are non-refundable.',
    zh: '1.兑换后，你当前的会员会被延长 {days} 天\n2.兑换的会员时长将在商店会员结束后开始生效\n3.商品兑换无法退款',
  ).replaceAll('{days}', days.toString());

  String get memberCenterModalExchangeConfirmButton => _remoteText(
    'member_center.modal.exchange.confirm_button',
    en: 'Confirm',
    zh: '确认',
  );

  String get memberCenterLabelValidUntil => _remoteText(
    'member_center.label.valid_until',
    en: 'Valid until',
    zh: '有效期至',
  );

  // ── 1.0.2 / 奖励金币 ─────────────────────────────────────────────
  String get rewardsTabRewardTaskTitle =>
      _remoteText('rewards.task.title', en: 'Earn Coins', zh: '赚取金币');

  String get rewardsTabRewardCoins =>
      _remoteText('rewards.tab.reward_coins', en: 'Reward Coins', zh: '奖励金币');

  String get rewardsCoinBalanceCurrent => _remoteText(
    'rewards.coin_balance.current',
    en: 'Coin balance',
    zh: '我的金币',
  );

  String get rewardsSigninButtonSignIn =>
      _remoteText('rewards.signin.button.sign_in', en: 'Check In', zh: '签到');

  String get rewardsSigninButtonSignedIn => _remoteText(
    'rewards.signin.button.signed_in',
    en: 'Checked In',
    zh: '已签到',
  );

  String get rewardsSigninSuccessTitle => _remoteText(
    'rewards.signin.success.title',
    en: 'Check-in Successful',
    zh: '签到成功',
  );

  String rewardsSigninSuccessCoins(Object coins) => _remoteText(
    'rewards.signin.success.coins',
    en: '{coins} coins',
    zh: '{coins}金币',
  ).replaceAll('{coins}', coins.toString());

  String get rewardsSigninSuccessConfirm =>
      _remoteText('rewards.signin.success.confirm', en: 'Claim', zh: '确认收下');

  String rewardsClaimSuccessCoins(Object coins) => _remoteText(
    'rewards.claim_success.coins',
    en: '{coins} coins',
    zh: '{coins}金币',
  ).replaceAll('{coins}', coins.toString());

  String rewardsSigninDaysCount(Object days) => _remoteText(
    'rewards.signin.days_count',
    en: 'Checked in for {days} day',
    zh: '已签到{days}天',
  ).replaceAll('{days}', days.toString());

  // ── 1.0.2 / 登录 ─────────────────────────────────────────────
  String get loginButtonGoogle => _remoteText(
    'login.button.google',
    en: 'Sign in with Google',
    zh: 'Google登录',
  );

  String get loginButtonApple => _remoteText(
    'login.button.apple',
    en: 'Sign in with Apple',
    zh: 'Apple登录',
  );

  // ── 1.0.2 / 问题与帮助 ─────────────────────────────────────────────
  String get helpTitle =>
      _remoteText('help.title', en: 'Help & Feedback', zh: '问题与帮助');

  String get helpSearchPlaceholder => _remoteText(
    'help.search.placeholder',
    en: 'Search questions',
    zh: '搜索问题',
  );

  String get helpFaqCategoryHot =>
      _remoteText('help.faq.category.hot', en: 'Popular Questions', zh: '热门问题');

  String get helpFaqCategoryPayment => _remoteText(
    'help.faq.category.payment',
    en: 'Payment Issues',
    zh: '付款问题',
  );

  String get helpFaqCategoryDrama =>
      _remoteText('help.faq.category.drama', en: 'Drama Issues', zh: '剧集问题');

  String get helpFeedbackButtonSubmitFeedback => _remoteText(
    'help.feedback.button.submit_feedback',
    en: 'Submit Feedback',
    zh: '我要反馈意见',
  );

  String get helpFaqEmpty => _remoteText(
    'help.faq.empty',
    en: 'No questions in this category',
    zh: '当前分类暂无问题',
  );

  String get helpFaqSearchEmpty =>
      _remoteText('help.faq.search.empty', en: 'No results found', zh: '无搜索结果');

  String get feedbackSubmitTitle =>
      _remoteText('feedback.submit.title', en: 'Submit Feedback', zh: '反馈提交');

  String get feedbackFieldType =>
      _remoteText('feedback.field.type', en: 'Issue Type', zh: '问题类型');

  String get feedbackFieldDescription =>
      _remoteText('feedback.field.description', en: 'Description', zh: '描述');

  String get feedbackFieldEmail =>
      _remoteText('feedback.field.email', en: 'Email', zh: 'Email');

  String get feedbackPlaceholderDescription => _remoteText(
    'feedback.placeholder.description',
    en: 'Please describe your issue',
    zh: '请描述你遇到的问题',
  );

  String get feedbackActionUploadImage => _remoteText(
    'feedback.action.upload_image',
    en: 'Upload Images',
    zh: '上传图片',
  );

  String get feedbackToastSubmitSuccess => _remoteText(
    'feedback.toast.submit_success',
    en: 'Submitted successfully',
    zh: '提交成功',
  );

  String get feedbackToastSubmitFailed => _remoteText(
    'feedback.toast.submit_failed',
    en: 'Submission failed. Please try again later.',
    zh: '提交失败，请稍后重试',
  );

  String get feedbackRecordsTitle =>
      _remoteText('feedback.records.title', en: 'My Feedback', zh: '我的反馈');

  String get feedbackRecordsEmpty =>
      _remoteText('feedback.records.empty', en: 'No records', zh: '没有相关记录');

  String get faqCatIds => _remoteText(
    'faq.cat.ids',
    en: 'payment,membership,coins,rewards,account',
    zh: 'payment,membership,coins,rewards,account',
  );

  String get faqPaymentTitle =>
      _remoteText('faq.payment.title', en: 'Payment Issues', zh: '支付问题');

  String get faqPaymentQIds => _remoteText(
    'faq.payment.q.ids',
    en: 'q001,q002,q003',
    zh: 'q001,q002,q003',
  );

  String get faqPaymentQ001Q => _remoteText(
    'faq.payment.q001.q',
    en: 'What should I do if my coins or membership are not credited after payment?',
    zh: '支付成功后金币或会员没有到账怎么办？',
  );

  String get faqPaymentQ001A => _remoteText(
    'faq.payment.q001.a',
    en: 'Please return to your wallet or membership page, or reopen the app to refresh your status. If it is still not credited, submit feedback in "Help & Feedback" and provide a payment screenshot, order number, or payment transaction ID. We will check it as soon as possible.',
    zh: '请先返回钱包、会员页或重新进入 App 刷新状态。如果仍未到账，请在“问题与帮助”中提交反馈，并提供支付截图、订单号或支付流水号，我们会尽快为你核查。',
  );

  String get faqPaymentQ002Q => _remoteText(
    'faq.payment.q002.q',
    en: 'Why can\'t I see a certain payment method?',
    zh: '为什么看不到某个支付方式？',
  );

  String get faqPaymentQ002A => _remoteText(
    'faq.payment.q002.a',
    en: 'Available payment methods are based on what is shown on the payment page. If a certain payment method is not currently available, please choose another payment method shown on the page to complete your payment.',
    zh: '当前可用的支付方式以支付页面实际展示为准。如果暂时看不到某个支付方式，请选择页面中已展示的其他支付方式完成支付。',
  );

  String get faqPaymentQ003Q => _remoteText(
    'faq.payment.q003.q',
    en: 'Can I request a refund?',
    zh: '可以申请退款吗？',
  );

  String get faqPaymentQ003A => _remoteText(
    'faq.payment.q003.a',
    en: 'If you need a refund, please submit feedback through "Help & Feedback" and provide your order information. Whether a refund is available and the final refund result depend on the payment platform rules and the actual order status.',
    zh: '如需退款，请通过“问题与帮助”提交反馈，并提供订单信息。是否可退款以及退款处理结果，以支付平台规则和订单实际状态为准。',
  );

  String get faqMembershipTitle =>
      _remoteText('faq.membership.title', en: 'Membership Issues', zh: '会员问题');

  String get faqMembershipQIds => _remoteText(
    'faq.membership.q.ids',
    en: 'q001,q002,q003,q004',
    zh: 'q001,q002,q003,q004',
  );

  String get faqMembershipQ001Q => _remoteText(
    'faq.membership.q001.q',
    en: 'How do I cancel auto-renewal?',
    zh: '如何取消自动续费？',
  );

  String get faqMembershipQ001A => _remoteText(
    'faq.membership.q001.a',
    en: 'Auto-renewal must be canceled through the corresponding payment platform. If you subscribed through Apple, go to App Store subscription management. If you subscribed through Google Play, go to Google Play subscription management. After cancellation, the app will no longer renew automatically.',
    zh: '自动续费需要在对应的支付平台中取消。如果你通过 Apple 订阅，请前往 App Store 订阅管理；如果你通过 Google Play 订阅，请前往 Google Play 订阅管理。取消后，App 内不会再自动扣款。',
  );

  String get faqMembershipQ002Q => _remoteText(
    'faq.membership.q002.q',
    en: 'Can I still use my membership after canceling auto-renewal?',
    zh: '取消自动续费后还能继续使用会员吗？',
  );

  String get faqMembershipQ002A => _remoteText(
    'faq.membership.q002.a',
    en: 'Yes. After canceling auto-renewal, you can continue using your membership benefits until the current paid period ends. If you do not renew after it expires, your membership benefits will stop.',
    zh: '可以。取消自动续费后，你仍可继续使用已支付周期内的会员权益，直到当前会员到期。到期后如果没有再次续费，会员权益将停止。',
  );

  String get faqMembershipQ003Q => _remoteText(
    'faq.membership.q003.q',
    en: 'Why can\'t I watch member-only dramas?',
    zh: '为什么会员剧仍然无法观看？',
  );

  String get faqMembershipQ003A => _remoteText(
    'faq.membership.q003.a',
    en: 'Please first check whether your membership is still valid, then try refreshing your membership status or reopening the app. If your membership is still valid but you cannot watch, submit feedback in "Help & Feedback" and we will check it for you.',
    zh: '请先确认会员是否仍在有效期内，并尝试刷新会员状态或重新进入 App。如果会员仍有效但无法观看，请在“问题与帮助”中提交反馈，我们会为你核查。',
  );

  String get faqMembershipQ004Q => _remoteText(
    'faq.membership.q004.q',
    en: 'When does membership redeemed with points take effect?',
    zh: '积分兑换的会员什么时候生效？',
  );

  String get faqMembershipQ004A => _remoteText(
    'faq.membership.q004.a',
    en: 'After redeeming membership with points, the membership duration will be added to your membership benefits. If you already have an active membership, the redeemed duration will be added after your current membership period.',
    zh: '积分兑换会员成功后，会员时长会增加到你的会员权益中。如当前已有会员，兑换的会员时长会顺延到现有会员时间之后。',
  );

  String get faqCoinsTitle =>
      _remoteText('faq.coins.title', en: 'Coin Issues', zh: '金币问题');

  String get faqCoinsQIds => _remoteText(
    'faq.coins.q.ids',
    en: 'q001,q002,q003,q004',
    zh: 'q001,q002,q003,q004',
  );

  String get faqCoinsQ001Q => _remoteText(
    'faq.coins.q001.q',
    en: 'What is the difference between coins and reward coins?',
    zh: '金币和奖励金币有什么区别？',
  );

  String get faqCoinsQ001A => _remoteText(
    'faq.coins.q001.a',
    en: 'Coins are usually purchased through top-up. Reward coins are usually earned from check-ins, tasks, campaigns, or gifts. Both can be used to unlock episodes, but reward coins may have an expiration date.',
    zh: '金币通常来自充值购买；奖励金币通常来自签到、任务、活动或赠送。两者都可以用于解锁剧集，但奖励金币可能存在有效期。',
  );

  String get faqCoinsQ002Q => _remoteText(
    'faq.coins.q002.q',
    en: 'Which type of coins will be used first when unlocking episodes?',
    zh: '解锁剧集时会优先扣哪种金币？',
  );

  String get faqCoinsQ002A => _remoteText(
    'faq.coins.q002.a',
    en: 'Reward coins will be used first when unlocking episodes. If reward coins are insufficient, purchased coins will be used.',
    zh: '解锁剧集时会优先使用奖励金币；奖励金币不足时，再使用充值获得的金币。',
  );

  String get faqCoinsQ003Q => _remoteText(
    'faq.coins.q003.q',
    en: 'Do reward coins expire?',
    zh: '奖励金币会过期吗？',
  );

  String get faqCoinsQ003A => _remoteText(
    'faq.coins.q003.a',
    en: 'Yes. Reward coins usually have an expiration date. The exact validity period is based on what is shown on the page or in the campaign rules. Unused reward coins cannot be used after they expire.',
    zh: '会。奖励金币通常有有效期，具体有效期以页面展示或活动规则为准。过期后未使用的奖励金币将无法继续使用。',
  );

  String get faqCoinsQ004Q => _remoteText(
    'faq.coins.q004.q',
    en: 'What should I do if I don\'t have enough coins?',
    zh: '金币不足时怎么办？',
  );

  String get faqCoinsQ004A => _remoteText(
    'faq.coins.q004.a',
    en: 'If you do not have enough coins, you can buy coins on the top-up page, or earn reward coins through check-ins, tasks, campaigns, and other activities.',
    zh: '如果金币不足，你可以前往充值页购买金币，或通过签到、任务、活动等方式获得奖励金币。',
  );

  String get faqRewardsTitle =>
      _remoteText('faq.rewards.title', en: 'Rewards & Points', zh: '奖励与积分');

  String get faqRewardsQIds => _remoteText(
    'faq.rewards.q.ids',
    en: 'q001,q002,q003,q004,q005',
    zh: 'q001,q002,q003,q004,q005',
  );

  String get faqRewardsQ001Q => _remoteText(
    'faq.rewards.q001.q',
    en: 'How can I earn member points?',
    zh: '如何获得会员积分？',
  );

  String get faqRewardsQ001A => _remoteText(
    'faq.rewards.q001.a',
    en: 'Member points can be earned through daily member rewards, point tasks, and other activities. The available rewards are based on what is shown on the Member Points page.',
    zh: '会员积分可通过会员每日奖励、积分任务等方式获得。具体可领取内容以会员积分页展示为准。',
  );

  String get faqRewardsQ002Q => _remoteText(
    'faq.rewards.q002.q',
    en: 'Why can\'t I claim member points?',
    zh: '为什么我不能领取会员积分？',
  );

  String get faqRewardsQ002A => _remoteText(
    'faq.rewards.q002.a',
    en: 'Member points are usually only available to paid members. Please check whether you are an active paid member and whether today\'s reward or task has already been claimed.',
    zh: '会员积分通常仅付费会员可领取。请确认你是否为有效付费会员，并检查当天奖励或任务是否已经领取。',
  );

  String get faqRewardsQ003Q => _remoteText(
    'faq.rewards.q003.q',
    en: 'When do daily rewards refresh?',
    zh: '每日奖励什么时候刷新？',
  );

  String get faqRewardsQ003A => _remoteText(
    'faq.rewards.q003.a',
    en: 'Daily rewards, check-ins, and tasks refresh at 00:00 India Standard Time. After the refresh, you can view the rewards available for the day.',
    zh: '每日奖励、签到和任务会在印度时区 0 点刷新。刷新后，你可以重新查看当天可领取内容。',
  );

  String get faqRewardsQ004Q => _remoteText(
    'faq.rewards.q004.q',
    en: 'What happens if my check-in streak is interrupted?',
    zh: '签到中断后会怎样？',
  );

  String get faqRewardsQ004A => _remoteText(
    'faq.rewards.q004.a',
    en: 'If your check-in streak is interrupted, your check-in progress may be reset and will start again from a new check-in cycle.',
    zh: '如果签到中断，签到进度可能会被重置，后续将从新的签到周期重新开始计算。',
  );

  String get faqRewardsQ005Q => _remoteText(
    'faq.rewards.q005.q',
    en: 'Why can\'t I claim the reward after completing a task?',
    zh: '任务完成后为什么不能领取奖励？',
  );

  String get faqRewardsQ005A => _remoteText(
    'faq.rewards.q005.a',
    en: 'The task status may not have synced yet, the task conditions may not be fully completed, or the reward may have already been claimed today. Please refresh the page later and try again. If you still cannot claim it, submit feedback.',
    zh: '可能是任务状态尚未同步、任务条件未完全满足，或当天已经领取过奖励。你可以稍后刷新页面重试，如仍无法领取，请提交反馈。',
  );

  String get faqAccountTitle =>
      _remoteText('faq.account.title', en: 'Account Issues', zh: '账号问题');

  String get faqAccountQIds => _remoteText(
    'faq.account.q.ids',
    en: 'q001,q002,q003',
    zh: 'q001,q002,q003',
  );

  String get faqAccountQ001Q => _remoteText(
    'faq.account.q001.q',
    en: 'Will my coins and membership remain after signing in?',
    zh: '登录后原来的金币、会员还在吗？',
  );

  String get faqAccountQ001A => _remoteText(
    'faq.account.q001.a',
    en: 'If your assets are bound to the current account, your coins, reward coins, membership, and member points will remain after signing in. If you notice any asset issue, please submit feedback and provide the related account information.',
    zh: '如果你的资产已绑定到当前账号，登录后金币、奖励金币、会员和会员积分会继续保留。若你发现资产异常，请提交反馈并提供相关账号信息。',
  );

  String get faqAccountQ002Q => _remoteText(
    'faq.account.q002.q',
    en: 'Why did sign-in fail?',
    zh: '为什么登录失败？',
  );

  String get faqAccountQ002A => _remoteText(
    'faq.account.q002.a',
    en: 'Sign-in may fail due to network issues, third-party account authorization failure, or account status issues. Please check your network and try again, or try another sign-in method.',
    zh: '登录失败可能与网络异常、第三方账号授权失败或账号状态异常有关。请检查网络后重试，或换一种登录方式尝试。',
  );

  String get faqAccountQ003Q => _remoteText(
    'faq.account.q003.q',
    en: 'Can my data be restored after account deletion?',
    zh: '注销账号后数据还能恢复吗？',
  );

  String get faqAccountQ003A => _remoteText(
    'faq.account.q003.a',
    en: 'After account deletion, related account data, assets, and membership benefits may not be recoverable. Please submit an account deletion request only after confirming that you no longer need the account.',
    zh: '账号注销后，相关账号数据、资产和会员权益可能无法恢复。请在确认不再使用该账号后再提交注销申请。',
  );

  // ── 网络错误 Network ─────────────────────────────────────────────
  String get networkError => _remoteText(
    'app.common.error.network_retry',
    en: 'Network error. Please try again later.',
    zh: '网络错误，请稍后重试。',
  );

  String get paymentGoogleUnavailable => _remoteText(
    'payment.google_unavailable',
    en: "Google services unavailable. Can't load products.",
    zh: 'Google服务不可用，商品加载失败',
  );

  String get adUnlockSuccess =>
      _remoteText('ad_unlock.success', en: 'Unlocked successfully', zh: '解锁成功');

  String get adUnlockModalTitle => _remoteText(
    'ad_unlock.modal.title',
    en: 'Watch this episode free?',
    zh: '免费观看本集？',
  );

  String get adUnlockActionWatch => _remoteText(
    'ad_unlock.action.watch',
    en: 'Watch Ad to unlock',
    zh: '看广告解锁',
  );

  String adUnlockTodayProgress({required int watched, required Object total}) =>
      _interpolate(
        _remoteText(
          'ad_unlock.today_progress',
          en: 'Watched today ({watched}/{total})',
          zh: '今日已看（{watched}/{total}）',
        ),
        {'watched': watched, 'total': total},
      );

  String adUnlockCloseCountdown({required int seconds}) => _interpolate(
    _remoteText(
      'ad_unlock.close_countdown',
      en: 'Close in {seconds}s',
      zh: '{seconds}秒后可关闭',
    ),
    {'seconds': seconds},
  );

  String adUnlockWatchCountdown({required int seconds}) => _interpolate(
    _remoteText(
      'ad_unlock.watch_countdown',
      en: 'Watch {seconds}s more to unlock',
      zh: '再观看{seconds}秒即可解锁本集',
    ),
    {'seconds': seconds},
  );

  String get adUnlockStatusWatching =>
      _remoteText('ad_unlock.status.watching', en: 'Watching', zh: '观看中');

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
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
