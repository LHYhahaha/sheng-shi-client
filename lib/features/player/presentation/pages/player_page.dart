import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_ui_controller.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_content.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_chrome.dart';
import '../widgets/player_detail_sheet.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    required this.dramaId,
    required this.episodeId,
    this.feedMode = PlayerFeedMode.singleDrama,
    this.hideShellNavigation = false,
    super.key,
  });

  const PlayerPage.forYou({super.key})
    : dramaId = null,
      episodeId = null,
      feedMode = PlayerFeedMode.forYou,
      hideShellNavigation = true;

  final String? dramaId;
  final String? episodeId;
  final PlayerFeedMode feedMode;
  final bool hideShellNavigation;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final PageController _pageController;
  AppShellBottomNavigationVisible? _shellChrome;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.hideShellNavigation) {
      final shellChrome = ref.read(
        appShellBottomNavigationVisibleProvider.notifier,
      );
      _shellChrome = shellChrome;
    }
    Future<void>.microtask(() {
      _shellChrome?.hide();
      ref
          .read(playerUiControllerProvider.notifier)
          .startSession(widget.episodeId ?? '1');
      ref.read(playerFeedControllerProvider.notifier).load(_feedConfig);
    });
  }

  @override
  void dispose() {
    _shellChrome?.show();
    _pageController.dispose();
    super.dispose();
  }

  PlayerFeedConfig get _feedConfig {
    return switch (widget.feedMode) {
      PlayerFeedMode.singleDrama => PlayerFeedConfig.singleDrama(
        dramaId: widget.dramaId!,
        episodeId: widget.episodeId!,
      ),
      PlayerFeedMode.forYou => const PlayerFeedConfig.forYou(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(playerFeedControllerProvider);
    final feedController = ref.read(playerFeedControllerProvider.notifier);
    final uiState = ref.watch(playerUiControllerProvider);
    final uiController = ref.read(playerUiControllerProvider.notifier);

    ref.listen(
      playerFeedControllerProvider.select((state) => state.currentItem),
      (previous, next) {
        if (next == null || previous?.id == next.id) {
          return;
        }

        ref
            .read(playerUiControllerProvider.notifier)
            .selectEpisode(next.episode);
      },
    );

    ref.listen(
      playerFeedControllerProvider.select((state) => state.currentIndex),
      (previous, next) {
        if (!_pageController.hasClients) {
          return;
        }

        final currentPage = _pageController.page?.round();
        if (currentPage != next) {
          _pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: PopScope(
        canPop: !widget.hideShellNavigation && !uiState.showsPaywall,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }

          if (uiState.showsPaywall) {
            uiController.hidePaywall();
            return;
          }

          if (widget.hideShellNavigation) {
            _exitForYouFeed();
          }
        },
        child: _buildBody(feedState, feedController, uiState, uiController),
      ),
    );
  }

  Widget _buildBody(
    PlayerFeedState feedState,
    PlayerFeedController feedController,
    PlayerUiState uiState,
    PlayerUiController uiController,
  ) {
    if (feedState.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (feedState.error != null) {
      return Center(
        child: IconButton(
          color: AppColors.textPrimary,
          icon: const Icon(Icons.refresh_rounded),
          onPressed: feedController.retry,
        ),
      );
    }

    if (feedState.items.isEmpty) {
      return const Center(
        child: Icon(Icons.movie_filter_rounded, color: AppColors.textPrimary),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: feedState.items.length,
          onPageChanged: feedController.setCurrentIndex,
          itemBuilder: (context, index) {
            final item = feedState.items[index];
            return PlayerChrome(
              content: item.content,
              episodeNumber: item.episode.number,
              isPlaying: uiState.isPlaying && index == feedState.currentIndex,
              onTogglePlay: uiController.togglePlay,
              onEpisodesTap: () {
                _showDetailSheet(
                  item.content,
                  initialTab: PlayerDetailTab.episodes,
                );
              },
              onShareTap: _showShareSheet,
              onMoreTap: () {
                _showDetailSheet(
                  item.content,
                  initialTab: PlayerDetailTab.synopsis,
                );
              },
              onUnlockTap: uiController.showMemberPaywall,
              onBackTap: widget.hideShellNavigation ? _exitForYouFeed : null,
              forYouLayout: widget.feedMode == PlayerFeedMode.forYou,
            );
          },
        ),
        if (uiState.showsPaywall)
          PlayerPaywallOverlay(
            label: uiState.paywall == PlayerPaywallState.memberUnlock
                ? context.l10n.playerMemberUnlock
                : context.l10n.playerUnlockNow,
            onTap: _showUnlockSheet,
            onDismiss: uiController.hidePaywall,
          ),
      ],
    );
  }

  void _exitForYouFeed() {
    _shellChrome?.show();
    context.go(RoutePaths.home);
  }

  void _closeSheetAndSelectEpisode(
    BuildContext sheetContext,
    PlayerEpisode episode,
  ) {
    Navigator.of(sheetContext).pop();
    if (!mounted) {
      return;
    }

    final targetIndex = ref
        .read(playerFeedControllerProvider.notifier)
        .selectEpisode(episode);
    ref.read(playerUiControllerProvider.notifier).selectEpisode(episode);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _showDetailSheet(
    PlayerContent content, {
    required PlayerDetailTab initialTab,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return PlayerDetailSheet(
          content: content,
          initialTab: initialTab,
          currentEpisode:
              ref
                  .read(playerFeedControllerProvider)
                  .currentItem
                  ?.episode
                  .number ??
              1,
          onEpisodeSelected: (episode) {
            _closeSheetAndSelectEpisode(sheetContext, episode);
          },
        );
      },
    );
  }

  Future<void> _showShareSheet() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const PlayerShareSheet(),
    );
  }

  Future<void> _showUnlockSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const PlayerUnlockSheet(),
    );

    if (!mounted) {
      return;
    }

    ref.read(playerUiControllerProvider.notifier).unlockPaywallAndPlay();
  }
}
