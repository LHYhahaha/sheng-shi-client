import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../core/account/account_ban_controller.dart';
import '../../core/analytics/analytics_page_tracker.dart';
import '../../core/analytics/analytics_entry_source.dart';
import '../../features/bottom_tab_config/application/bottom_tab_config_controller.dart';
import '../../features/player/application/player_feed_controller.dart';
import '../../features/player/application/playback_experience_coordinator.dart';
import '../../features/player/application/playback_experience_state.dart';
import '../../features/player/application/player_playback_controller.dart';
import '../../features/player/domain/player_feed.dart';
import '../../features/popup/application/popup_entry_controller.dart';
import '../../core/runtime/startup_loading_timing.dart';
import '../../features/popup/domain/popup.dart';
import '../../shared/widgets/app_peg_top_loader.dart';
import '../../shared/widgets/navigation/app_bottom_navigation.dart';
import 'app_shell_chrome.dart';

/// 当前 Shell Tab 索引的 notifier。
class _CurrentTabIndexNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void setIndex(int index) {
    state = index;
  }
}

/// 当前 Shell Tab 索引的 provider。
final appShellCurrentTabIndexProvider =
    NotifierProvider<_CurrentTabIndexNotifier, int>(
      _CurrentTabIndexNotifier.new,
    );

/// 首页滚动到顶部的请求计数 notifier。
class _HomeScrollToTopNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void requestScrollToTop() {
    state++;
  }
}

/// 首页滚动到顶部的通知 provider。
///
/// 当重复点击首页 tab 时，这个 provider 会增加计数，
/// HomePage 会监听这个变化并执行滚动到顶部的操作。
final homeScrollToTopRequestProvider =
    NotifierProvider<_HomeScrollToTopNotifier, int>(
      _HomeScrollToTopNotifier.new,
    );

/// 会员 tab 刷新请求计数 notifier。
class _MemberTabRefreshRequestNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void requestRefresh() {
    state++;
  }
}

/// 会员 tab 刷新通知 provider。
///
/// 当重复点击会员 tab 时，这个 provider 会增加计数，MemberTabPage 会静默刷新商品价钱。
final memberTabRefreshRequestProvider =
    NotifierProvider<_MemberTabRefreshRequestNotifier, int>(
      _MemberTabRefreshRequestNotifier.new,
    );

/// 主导航 shell。
///
/// Shell 只管理 tab 容器和底部导航显示，不拥有播放器 session。离开 For You tab 时
/// 通过播放器 controller 调 pauseForVisibility，让播放链路自己释放预热和窗口资源。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  /// go_router 提供的 StatefulShell。
  ///
  /// 它负责保留四个主 tab 的页面栈；Shell 只在切 tab 时补充播放器可见性处理。
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Future<void> _forYouVisibilityOperation = Future<void>.value();
  late int _lastNavigationIndex;
  bool _shellReadyEffectsStarted = false;
  bool _forYouFeedPreloadStarted = false;

  @override
  void initState() {
    super.initState();
    _lastNavigationIndex = widget.navigationShell.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final bottomTabConfig = ref.watch(bottomTabConfigControllerProvider);
    // 冷启动先完成动态 Tab 配置判定。无论接口成功还是失败，hasLoaded 均会置为 true；
    // 失败时随后展示完整默认导航，避免默认首页先绘制再被 H5 替换。
    if (!bottomTabConfig.hasLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0014),
        body: Center(child: AppPegTopLoader()),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final elapsed = startupLoadingTiming.end();
      if (elapsed != null) {
        debugPrint(
          '[StartupLoading] app-shell visible; '
          'app-loading end elapsedMs=${elapsed.inMilliseconds}',
        );
      }
    });

    final navigationIndex = widget.navigationShell.currentIndex;
    if (!_shellReadyEffectsStarted) {
      _shellReadyEffectsStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _requestPopupForIndex(widget.navigationShell.currentIndex);
        _trackPageForIndex(widget.navigationShell.currentIndex);
        _scheduleForYouFeedPreload();
      });
    }
    if (_lastNavigationIndex != navigationIndex) {
      final previousIndex = _lastNavigationIndex;
      final previousPlacement = AppShellDestinations.popupPlacementForIndex(
        previousIndex,
      );
      // Router 驱动的 branch 变更会使 Shell 在 build 中重建。弹框 controller
      // 和播放器可见性均会写 provider，必须等本帧结束后再执行；否则从问题与
      // 帮助页返回 Profile 时会触发 Riverpod 的 build 期写入断言。
      _lastNavigationIndex = navigationIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.navigationShell.currentIndex != navigationIndex) {
          return;
        }
        if (previousPlacement != null) {
          ref
              .read(popupEntryControllerProvider.notifier)
              .cancelPlacementFlow(previousPlacement);
        }
        _syncForYouVisibilityForNavigationChange(
          from: previousIndex,
          to: navigationIndex,
        );
        _trackPageForIndex(navigationIndex);
      });
    }
    final showBottomNavigation = ref.watch(
      appShellBottomNavigationVisibleProvider,
    );

    // 单剧播放器覆盖 Shell 时，需要立即取消首页/For You 的弹框 flow。
    // 返回时仍交给 controller 的「当前前台周期是否已请求」保护：普通返回不会
    // 重复弹窗；若后台停留超过 30 分钟已重置请求周期，则回到对应 Tab 时会重拉。
    ref.listen<bool>(appShellBottomNavigationVisibleProvider, (previous, next) {
      if (previous == true && !next) {
        final placement = AppShellDestinations.popupPlacementForIndex(
          widget.navigationShell.currentIndex,
        );
        if (placement != null) {
          ref
              .read(popupEntryControllerProvider.notifier)
              .cancelPlacementFlow(placement);
        }
        return;
      }
      if (previous == false && next) {
        _requestPopupForIndex(widget.navigationShell.currentIndex);
      }
    });

    // 延迟更新当前 Tab 索引，避免在 build 中修改 provider
    Future.microtask(() {
      ref
          .read(appShellCurrentTabIndexProvider.notifier)
          .setIndex(navigationIndex);
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: showBottomNavigation
          ? AppBottomNavigation(
              currentIndex: navigationIndex,
              onDestinationSelected: (index) {
                _goBranch(index);
              },
            )
          : null,
    );
  }

  void _goBranch(int index) {
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    final currentIndex = widget.navigationShell.currentIndex;
    _syncForYouVisibilityForNavigationChange(from: currentIndex, to: index);
    _lastNavigationIndex = index;

    // 检测是否重复点击首页 tab，如果是则通知首页滚动到顶部
    if (index == currentIndex && index == AppShellDestinations.homeIndex) {
      ref.read(homeScrollToTopRequestProvider.notifier).requestScrollToTop();
    }
    if (index == currentIndex && index == AppShellDestinations.memberIndex) {
      ref.read(memberTabRefreshRequestProvider.notifier).requestRefresh();
    }

    if (index != currentIndex) {
      final previousPlacement = AppShellDestinations.popupPlacementForIndex(
        currentIndex,
      );
      if (previousPlacement != null) {
        ref
            .read(popupEntryControllerProvider.notifier)
            .cancelPlacementFlow(previousPlacement);
      }
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == currentIndex,
    );
    _requestPopupForIndex(index);
    _trackPageForIndex(index);
  }

  /// 在首页首帧稳定后预取 For You 的推荐首屏。
  ///
  /// 此处只请求推荐接口并保留 feed 数据；不创建媒体播放器、不打开视频 URL，也不
  /// 触发解码。尤其是通知或 Deep Link 冷启动直进播放器时，隐藏的 For You decoder
  /// 会与目标播放器同时占用 MediaCodec/VideoOutput，增加原生崩溃风险。进入 For
  /// You 时 [PlayerFeedController.load] 会复用这份状态，省去一次推荐接口等待。
  void _scheduleForYouFeedPreload() {
    if (_forYouFeedPreloadStarted ||
        ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    _forYouFeedPreloadStarted = true;
    unawaited(_preloadForYouFeedAfterHomeFrame());
  }

  Future<void> _preloadForYouFeedAfterHomeFrame() async {
    // 首帧已经提交后立即开始：For You 的首条媒体预热本身还需要数秒，不能再额外
    // 等待。若用户已主动进入 For You，页面会自行加载。
    if (!mounted ||
        widget.navigationShell.currentIndex ==
            AppShellDestinations.forYouIndex ||
        ref.read(accountBanControllerProvider).isBanned) {
      return;
    }

    final feedProvider = playerFeedControllerProvider(
      PlayerPlaybackSessionKeys.forYouTab,
    );
    await ref.read(feedProvider.notifier).load(const PlayerFeedConfig.forYou());
    if (!mounted ||
        widget.navigationShell.currentIndex ==
            AppShellDestinations.forYouIndex ||
        !ref.read(appShellBottomNavigationVisibleProvider)) {
      return;
    }
    final firstItem = ref.read(feedProvider).currentItem;
    if (firstItem == null) {
      return;
    }
    if (!shouldWarmForYouEntryNativeSession(defaultTargetPlatform)) {
      return;
    }
    // feed 与首条 HLS 已经在首页首帧后完成。此处只为 For You 的稳定 session
    // 准备一个静音 decoder；用户切入时由同一 controller 接管，避免首条再从冷
    // HLS/decoder 开始。普通播放器覆盖 Shell 时底栏会隐藏，上方门控会跳过它。
    await ref
        .read(
          playerPlaybackControllerProvider(
            PlayerPlaybackSessionKeys.forYouTab,
          ).notifier,
        )
        .warmUpForYouEntry(firstItem);
  }

  /// Handles both bottom-navigation taps and router-driven branch changes.
  ///
  /// `context.go('/home')` does not call [_goBranch], while the For You branch
  /// stays alive in StatefulShell's indexed stack. Watching the shell index is
  /// essential so that route-driven exits cannot leave its audio playing.
  void _syncForYouVisibilityForNavigationChange({
    required int from,
    required int to,
  }) {
    if (from == to) {
      return;
    }
    final playbackProvider = playerPlaybackControllerProvider(
      PlayerPlaybackSessionKeys.forYouTab,
    );
    final experience = ref.read(
      playbackExperienceCoordinatorProvider(
        PlayerPlaybackSessionKeys.forYouTab,
      ).notifier,
    );
    if (from == AppShellDestinations.forYouIndex &&
        to != AppShellDestinations.forYouIndex) {
      experience.setVisibility(PlaybackExperienceVisibility.hidden);
      unawaited(experience.synchronize());
      // 先同步关闭播放闸门，再排队做耗时的 session/preload 清理。否则 loading
      // 中的 open 在清理完成前返回时，可能会在已隐藏的 For You 里开始播放。
      ref.read(playbackProvider.notifier).markHiddenForVisibility();
      _forYouVisibilityOperation = _forYouVisibilityOperation.then((_) {
        return ref.read(playbackProvider.notifier).pauseForVisibility();
      });
      return;
    }
    if (from != AppShellDestinations.forYouIndex &&
        to == AppShellDestinations.forYouIndex) {
      experience.setVisibility(PlaybackExperienceVisibility.visible);
      unawaited(experience.synchronize());
      // 离开时可能还没有 currentSource（视频正处于 source resolve/open 前）。
      // 即使没有可恢复的媒体，也必须重新打开可见性闸门；否则回到 For You 后的
      // playItem 会被永久当作隐藏播放而保持 paused，表现为黑屏。
      _forYouVisibilityOperation = _forYouVisibilityOperation.then((_) {
        return ref.read(playbackProvider.notifier).resumeAfterCompetingPlayer();
      });
    }
  }

  void _requestPopupForIndex(int index) {
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    // Shell 的首帧副作用会排到当前帧结束后执行。用户可能在这之前已经从首页
    // push 到搜索等 Shell 外页面；此时不能再启动首页入口位请求，否则根 Overlay
    // 会在请求/图片预加载完成后覆盖新页面。
    final currentPath = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    if (currentPath != RoutePaths.home && currentPath != RoutePaths.forYou) {
      return;
    }
    final placement = AppShellDestinations.popupPlacementForIndex(index);
    if (placement == null) {
      return;
    }
    unawaited(
      ref
          .read(popupEntryControllerProvider.notifier)
          .requestForPlacement(placement),
    );
  }

  void _trackPageForIndex(int index) {
    final pageName = switch (index) {
      AppShellDestinations.homeIndex => AnalyticsPageNames.home,
      AppShellDestinations.forYouIndex => AnalyticsPageNames.recommend,
      AppShellDestinations.memberIndex => AnalyticsPageNames.vipTab,
      AppShellDestinations.myListIndex => AnalyticsPageNames.favorite,
      AppShellDestinations.profileIndex => AnalyticsPageNames.my,
      _ => null,
    };
    if (pageName != null) {
      unawaited(
        ref
            .read(analyticsPageTrackerProvider)
            .replace(
              pageName,
              forcePageView: ref
                  .read(analyticsEntrySourceProvider.notifier)
                  .hasPending,
            ),
      );
    }
  }
}

class AppShellDestinations {
  const AppShellDestinations._();

  static const homeIndex = 0;
  static const forYouIndex = 1;
  static const memberIndex = 2;
  static const myListIndex = 3;
  static const profileIndex = 4;

  static const paths = [
    RoutePaths.home,
    RoutePaths.forYou,
    RoutePaths.member,
    RoutePaths.myList,
    RoutePaths.profile,
  ];

  static PopupPlacementCode? popupPlacementForIndex(int index) {
    return switch (index) {
      homeIndex => PopupPlacementCode.homeEnter,
      forYouIndex => PopupPlacementCode.recommendTabEnter,
      _ => null,
    };
  }
}
