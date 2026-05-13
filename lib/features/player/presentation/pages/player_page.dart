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
      hideShellNavigation = false;

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

  String get _sessionKey {
    return switch (widget.feedMode) {
      PlayerFeedMode.forYou => 'for-you-tab',
      PlayerFeedMode.singleDrama =>
        'single:${widget.dramaId}:${widget.episodeId}',
    };
  }

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
          .read(playerUiControllerProvider(_sessionKey).notifier)
          .startSession(widget.episodeId ?? '1');
      ref
          .read(playerFeedControllerProvider(_sessionKey).notifier)
          .load(_feedConfig);
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
    final sessionKey = _sessionKey;
    final feedProvider = playerFeedControllerProvider(sessionKey);
    final uiProvider = playerUiControllerProvider(sessionKey);
    final feedState = ref.watch(feedProvider);
    final feedController = ref.read(feedProvider.notifier);
    final uiState = ref.watch(uiProvider);
    final uiController = ref.read(uiProvider.notifier);

    ref.listen(feedProvider.select((state) => state.currentItem), (
      previous,
      next,
    ) {
      if (next == null || previous?.id == next.id) {
        return;
      }

      ref.read(uiProvider.notifier).selectEpisode(next.episode);
    });

    ref.listen(feedProvider.select((state) => state.currentIndex), (
      previous,
      next,
    ) {
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
    });

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
      return _PlayerStateMessage(
        icon: Icons.refresh_rounded,
        message: context.l10n.playerFeedLoadFailed,
        actionLabel: context.l10n.retry,
        onAction: feedController.retry,
      );
    }

    if (feedState.items.isEmpty) {
      return _PlayerStateMessage(
        icon: Icons.movie_filter_rounded,
        message: context.l10n.playerFeedEmpty,
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
            return Stack(
              children: [
                PlayerChrome(
                  content: item.content,
                  episodeNumber: item.episode.number,
                  isPlaying:
                      uiState.isPlaying &&
                      index == feedState.currentIndex &&
                      !item.episode.isUnavailable,
                  onTogglePlay: item.episode.isUnavailable
                      ? () {}
                      : uiController.togglePlay,
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
                  onBackTap: widget.hideShellNavigation
                      ? _exitForYouFeed
                      : null,
                  forYouLayout: widget.feedMode == PlayerFeedMode.forYou,
                ),
                if (item.episode.isUnavailable)
                  _UnavailableEpisodeOverlay(
                    message: context.l10n.playerEpisodeUnavailable,
                  ),
              ],
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
        .read(playerFeedControllerProvider(_sessionKey).notifier)
        .selectEpisode(episode);
    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .selectEpisode(episode);
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
                  .read(playerFeedControllerProvider(_sessionKey))
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

    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .unlockPaywallAndPlay();
  }
}

class _PlayerStateMessage extends StatelessWidget {
  const _PlayerStateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 32),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.82),
                fontSize: 14,
                height: 18 / 14,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnavailableEpisodeOverlay extends StatelessWidget {
  const _UnavailableEpisodeOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.32),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 42),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 18 / 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
