import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_definition.dart';
import 'analytics_event.dart';
import 'analytics_page_context.dart';
import 'analytics_provider.dart';
import 'analytics_service.dart';

/// 页面字典中当前客户端可映射的页面名。
abstract final class AnalyticsPageNames {
  static const home = 'home_page';
  static const recommend = 'recommend_page';
  static const search = 'search_page';
  static const dramaPlay = 'drama_play_page';
  static const vipTab = 'vip_tab_page';
  static const vipCenter = 'vip_center_page';
  static const vipPurchase = 'vip_purchase_page';
  static const favorite = 'favorite_page';
  static const my = 'my_page';
  static const wallet = 'wallet_page';
  static const coinRecharge = 'coin_recharge_page';
  static const rewardCoin = 'reward_coin_page';
  static const memberPoints = 'member_points_page';
  static const settings = 'settings_page';
  static const languageSettings = 'language_settings_page';
  static const accountDeletion = 'account_deletion_page';
  static const login = 'login_page';
}

class AnalyticsPageTracker {
  AnalyticsPageTracker({
    required AnalyticsService analytics,
    required AnalyticsPageContextController pageContext,
    DateTime Function()? now,
  }) : _analytics = analytics,
       _pageContext = pageContext,
       _now = now ?? DateTime.now;

  final AnalyticsService _analytics;
  final AnalyticsPageContextController _pageContext;
  final DateTime Function() _now;
  final List<String> _pageStack = <String>[];
  DateTime? _enteredAt;
  Future<void> _pendingOperation = Future<void>.value();

  List<String> get pageStack => List.unmodifiable(_pageStack);

  /// Navigator push：保存当前页面并将新页面入栈。
  Future<void> push(String pageName) => _enqueue(() => _push(pageName));

  Future<void> _push(String pageName) async {
    final currentPage = _pageContext.current.currentPage;
    if (currentPage == pageName) return;
    await _leaveCurrent();
    _pageStack.add(pageName);
    await _show(pageName, previousPage: currentPage);
  }

  /// 路由替换或底部 Tab 切换：替换当前展示页，不新增返回栈层级。
  Future<void> replace(String pageName) => _enqueue(() => _replace(pageName));

  Future<void> _replace(String pageName) async {
    final currentPage = _pageContext.current.currentPage;
    if (currentPage == pageName) return;
    await _leaveCurrent();
    if (_pageStack.isNotEmpty) _pageStack.removeLast();
    _pageStack.add(pageName);
    await _show(pageName, previousPage: currentPage);
  }

  /// Navigator pop：先离开栈顶，再恢复栈中的返回页。
  Future<void> pop(String poppedPage, {String? returnedPage}) =>
      _enqueue(() => _pop(poppedPage, returnedPage: returnedPage));

  Future<void> _pop(String poppedPage, {String? returnedPage}) async {
    final currentPage = _pageContext.current.currentPage;
    if (currentPage != poppedPage) return;
    await _leaveCurrent();
    if (_pageStack.isNotEmpty && _pageStack.last == poppedPage) {
      _pageStack.removeLast();
    }

    final stackPage = _pageStack.isEmpty ? null : _pageStack.last;
    final targetPage = returnedPage ?? stackPage;
    if (targetPage == null) {
      _pageContext.clear();
      return;
    }
    if (returnedPage != null && stackPage != returnedPage) {
      if (_pageStack.isNotEmpty) _pageStack.removeLast();
      _pageStack.add(returnedPage);
    }
    await _show(targetPage, previousPage: poppedPage);
  }

  Future<void> _leaveCurrent() async {
    if (_pageContext.current.currentPage == null) return;
    final enteredAt = _enteredAt;
    if (enteredAt != null) {
      await _analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.pageLeave, {
          'stay_duration_ms': _now().difference(enteredAt).inMilliseconds,
        }),
      );
    }
    _enteredAt = null;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _pendingOperation.then((_) => operation());
    // 保持后续页面事件可继续执行；单个埋点失败不应阻塞整个页面追踪链路。
    _pendingOperation = next.catchError((_) {});
    return next;
  }

  Future<void> _show(String pageName, {required String? previousPage}) async {
    _pageContext.show(pageName, previousPage: previousPage);
    _enteredAt = _now();
    await _analytics.track(const AnalyticsEvent(AnalyticsDefinitions.pageView));
  }
}

final analyticsPageTrackerProvider = Provider<AnalyticsPageTracker>((ref) {
  final pageController = ref.read(analyticsPageContextProvider.notifier);
  return AnalyticsPageTracker(
    analytics: ref.watch(analyticsServiceProvider),
    pageContext: pageController,
  );
});

/// GoRouter 根 Navigator 的页面追踪观察器。
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver({
    required this.onRoutePushed,
    required this.onRouteReplaced,
    required this.onRoutePopped,
  });

  final void Function(String routeName) onRoutePushed;
  final void Function(String routeName) onRouteReplaced;
  final void Function(String poppedRouteName, String? previousRouteName)
  onRoutePopped;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(route, onRoutePushed);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _report(newRoute, onRouteReplaced);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final poppedName = route.settings.name;
    final poppedPage = poppedName == null
        ? null
        : analyticsPageNameForRoute(poppedName);
    if (poppedPage == null) return;
    final previousName = previousRoute?.settings.name;
    final previousPage = previousName == null
        ? null
        : analyticsPageNameForRoute(previousName);
    onRoutePopped(poppedPage, previousPage);
  }

  void _report(Route<dynamic> route, void Function(String pageName) reporter) {
    final name = route.settings.name;
    final pageName = name == null ? null : analyticsPageNameForRoute(name);
    if (pageName != null) reporter(pageName);
  }
}

String? analyticsPageNameForRoute(String routeName) => switch (routeName) {
  'home' => AnalyticsPageNames.home,
  'for-you' => AnalyticsPageNames.recommend,
  'search' => AnalyticsPageNames.search,
  'player' => AnalyticsPageNames.dramaPlay,
  'member' => AnalyticsPageNames.vipTab,
  'my-member' => AnalyticsPageNames.vipCenter,
  'membership' => AnalyticsPageNames.vipPurchase,
  'my-list' => AnalyticsPageNames.favorite,
  'profile' => AnalyticsPageNames.my,
  'wallet' => AnalyticsPageNames.wallet,
  'store' => AnalyticsPageNames.coinRecharge,
  'auth' => AnalyticsPageNames.login,
  'rewards' => AnalyticsPageNames.rewardCoin,
  'member-point-details' => AnalyticsPageNames.memberPoints,
  'settings' => AnalyticsPageNames.settings,
  'language' => AnalyticsPageNames.languageSettings,
  'account-cancellation' => AnalyticsPageNames.accountDeletion,
  _ => null,
};

final analyticsNavigatorObserverProvider = Provider<AnalyticsNavigatorObserver>(
  (ref) {
    return AnalyticsNavigatorObserver(
      onRoutePushed: (pageName) {
        // Navigator observer 在首帧构建过程中也可能回调；不能在该阶段直接
        // 修改 Riverpod 的页面上下文，否则会触发 provider build 期修改异常。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(ref.read(analyticsPageTrackerProvider).push(pageName));
        });
      },
      onRouteReplaced: (pageName) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(ref.read(analyticsPageTrackerProvider).replace(pageName));
        });
      },
      onRoutePopped: (poppedPage, previousPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final tracker = ref.read(analyticsPageTrackerProvider);
          await tracker.pop(poppedPage, returnedPage: previousPage);
        });
      },
    );
  },
);
