import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_environment.dart';
import '../../core/analytics/analytics_page_tracker.dart';
import '../app_root_navigator_key.dart';
import '../shell/app_shell.dart';
import '../../features/auth/presentation/pages/account_cancellation_page.dart';
import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/bottom_tab_config/presentation/bottom_tab_content_slot.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/member/presentation/pages/member_page.dart';
import '../../features/membership/presentation/pages/membership_page.dart';
import '../../features/my_list/presentation/pages/my_list_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/player/presentation/pages/ad_unlock_page.dart';
import '../../features/player/domain/player_content.dart';
import '../../features/player/domain/for_you_player_handoff.dart';
import '../../features/player/application/player_entry_preload_coordinator.dart';
import '../../features/profile/presentation/pages/language_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_feedback_webview_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/rewards/presentation/pages/member_point_details_page.dart';
import '../../features/rewards/presentation/pages/rewards_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../shared/widgets/webview_page.dart';
import '../../l10n/app_localizations.dart';
import '../../features/store/presentation/pages/store_page.dart';
import '../../features/wallet/domain/wallet_record.dart';
import '../../features/wallet/presentation/pages/wallet_history_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import 'route_names.dart';
import 'route_paths.dart';
import 'player_route_observer.dart';

/// 应用路由表。
///
/// 页面跳转统一通过 RoutePaths/RouteNames，避免散落字符串。播放器路由尤其敏感：
/// For You 在 shell 内保留底部导航，单剧播放器在 shell 外全屏并由 PlayerPage 管理
/// hide/show bottom navigation。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: RoutePaths.home,
    observers: [
      BotToastNavigatorObserver(),
      playerRouteObserver,
      ref.watch(analyticsNavigatorObserverProvider),
    ],
    routes: [
      // 底部五个主 tab 使用 indexedStack 保持页面状态。
      //
      // For You 播放器因此不会因为切到 Home/Profile 就被销毁；离开 tab 时的暂停
      // 由 AppShell 统一触发，避免路由层和播放器层互相直接依赖。
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => BottomTabContentSlot(
                  slot: 'home',
                  defaultTitle: context.l10n.navHome,
                  child: const HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.forYou,
                name: RouteNames.forYou,
                builder: (context, state) => BottomTabContentSlot(
                  slot: 'recommend_tab',
                  defaultTitle: context.l10n.navForYou,
                  child: const PlayerPage.forYou(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.member,
                name: RouteNames.member,
                builder: (context, state) => BottomTabContentSlot(
                  slot: 'member_tab',
                  defaultTitle: context.l10n.navMember,
                  child: const MemberTabPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.myList,
                name: RouteNames.myList,
                builder: (context, state) => BottomTabContentSlot(
                  slot: 'favorites',
                  defaultTitle: context.l10n.navMyList,
                  child: const MyListPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) => BottomTabContentSlot(
                  slot: 'profile',
                  defaultTitle: context.l10n.navProfile,
                  child: const ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.adUnlock,
        name: RouteNames.adUnlock,
        builder: (context, state) {
          final offer = state.extra! as PlayerAdUnlockOffer;
          return AdUnlockPage(offer: offer);
        },
      ),
      GoRoute(
        path: RoutePaths.player,
        name: RouteNames.player,
        builder: (context, state) {
          final dramaId = state.pathParameters['dramaId']!;
          final episodeId = state.pathParameters['episodeId']!;
          final userActionAtMs = int.tryParse(
            state.uri.queryParameters['userActionAtMs'] ?? '',
          );
          final forYouHandoff = state.extra is ForYouPlayerHandoff
              ? state.extra! as ForYouPlayerHandoff
              : null;

          // 所有普通播放器路由统一从这里提交用户点击预取；For You handoff 已持有
          // 当前播放器位置/session，不能重复启动普通详情/HLS 预热。
          if (forYouHandoff == null) {
            // GoRouter builder 属于 widget build 期，不能同步修改 Riverpod state。
            // 用下一轮 event loop 派发，而不是等首帧 post-frame callback：这样详情、
            // 播放进度和 HLS 首段会与 PlayerPage 首次 build 并行，但不会在 build 期
            // 修改 provider。Coordinator 会对路由重建去重。
            Future<void>(() {
              ref
                  .read(playerEntryPreloadCoordinatorProvider.notifier)
                  .preparePlayerRoute(
                    dramaId: dramaId,
                    episodeId: episodeId,
                    trigger: state.uri.queryParameters['trigger'],
                  );
            });
          }

          // 单剧播放器是 shell 外 route，进入时隐藏/显示底部导航由 PlayerPage 的
          // hideShellNavigation 和 dispose 处理。这里仅传递触发来源和点击时间，
          // 用于 playback timing trace 关联“用户点击 -> 首帧”。
          return PlayerPage(
            dramaId: dramaId,
            episodeId: episodeId,
            initialPlaybackTrigger: state.uri.queryParameters['trigger'],
            initialUserActionAt: userActionAtMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(userActionAtMs),
            forYouHandoff: forYouHandoff,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.search,
        name: RouteNames.search,
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: RoutePaths.store,
        name: RouteNames.store,
        builder: (context, state) => const StorePage(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: RouteNames.auth,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: RoutePaths.account,
        name: RouteNames.account,
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: RoutePaths.wallet,
        name: RouteNames.wallet,
        builder: (context, state) => const WalletPage(),
      ),
      GoRoute(
        path: RoutePaths.membership,
        name: RouteNames.membership,
        builder: (context, state) => const MembershipPage(),
      ),
      GoRoute(
        path: RoutePaths.myMember,
        name: RouteNames.myMember,
        builder: (context, state) => const MemberPage(),
      ),
      GoRoute(
        path: RoutePaths.rewards,
        name: RouteNames.rewards,
        builder: (context, state) => RewardsPage(
          initialTab: RewardTab.fromRouteValue(
            state.uri.queryParameters['tab'],
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.memberPointDetails,
        name: RouteNames.memberPointDetails,
        builder: (context, state) => const MemberPointDetailsPage(),
      ),
      GoRoute(
        path: RoutePaths.webview,
        name: RouteNames.webview,
        builder: (context, state) {
          return WebViewPage(
            url: state.uri.queryParameters['url'] ?? '',
            title: state.uri.queryParameters['title'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.profileFeedback,
        name: RouteNames.profileFeedback,
        builder: (context, state) => const ProfileFeedbackWebViewPage(),
      ),
      GoRoute(
        path: RoutePaths.language,
        name: RouteNames.language,
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: RoutePaths.accountCancellation,
        name: RouteNames.accountCancellation,
        builder: (context, state) => const AccountCancellationPage(),
      ),
      GoRoute(
        path: RoutePaths.userAgreement,
        name: RouteNames.userAgreement,
        builder: (context, state) {
          final languageCode = Localizations.localeOf(context).languageCode;
          return WebViewPage(
            url: AppConfig.current
                .termsOfUseUrlForLanguage(languageCode)
                .toString(),
            title: context.l10n.settingsUserAgreement,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        name: RouteNames.privacyPolicy,
        builder: (context, state) {
          final languageCode = Localizations.localeOf(context).languageCode;
          return WebViewPage(
            url: AppConfig.current
                .privacyPolicyUrlForLanguage(languageCode)
                .toString(),
            title: context.l10n.settingsPrivacyPolicy,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.transactionHistory,
        name: RouteNames.transactionHistory,
        builder: (context, state) =>
            const WalletHistoryPage(type: WalletRecordType.transaction),
      ),
      GoRoute(
        path: RoutePaths.consumptionHistory,
        name: RouteNames.consumptionHistory,
        builder: (context, state) =>
            const WalletHistoryPage(type: WalletRecordType.consumption),
      ),
      GoRoute(
        path: RoutePaths.recordCoins,
        name: RouteNames.recordCoins,
        builder: (context, state) =>
            const WalletHistoryPage(type: WalletRecordType.coins),
      ),
    ],
  );
});
