import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/player_ui_controller.dart';
import '../../data/player_content_repository_provider.dart';
import '../../domain/player_content.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_chrome.dart';
import '../widgets/player_detail_sheet.dart';

final _playerContentProvider = FutureProvider.family<PlayerContent, String>((
  ref,
  dramaId,
) {
  return ref
      .watch(playerContentRepositoryProvider)
      .getPlayerContent(dramaId: dramaId);
});

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({required this.dramaId, required this.episodeId, super.key});

  final String dramaId;
  final String episodeId;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref
          .read(playerUiControllerProvider.notifier)
          .startSession(widget.episodeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentState = ref.watch(_playerContentProvider(widget.dramaId));
    final uiState = ref.watch(playerUiControllerProvider);
    final uiController = ref.read(playerUiControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: PopScope(
        canPop: !uiState.showsPaywall,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || !uiState.showsPaywall) {
            return;
          }

          uiController.hidePaywall();
        },
        child: contentState.when(
          data: (content) => Stack(
            children: [
              Positioned.fill(
                child: PlayerChrome(
                  content: content,
                  episodeNumber: uiState.episodeNumber,
                  isPlaying: uiState.isPlaying,
                  onTogglePlay: uiController.togglePlay,
                  onEpisodesTap: () {
                    _showDetailSheet(
                      content,
                      initialTab: PlayerDetailTab.episodes,
                    );
                  },
                  onShareTap: _showShareSheet,
                  onMoreTap: () {
                    _showDetailSheet(
                      content,
                      initialTab: PlayerDetailTab.synopsis,
                    );
                  },
                  onUnlockTap: uiController.showMemberPaywall,
                ),
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
          ),
          loading: () => const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stackTrace) => Center(
            child: IconButton(
              color: AppColors.textPrimary,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(_playerContentProvider(widget.dramaId));
              },
            ),
          ),
        ),
      ),
    );
  }

  void _closeSheetAndSelectEpisode(
    BuildContext sheetContext,
    PlayerEpisode episode,
  ) {
    Navigator.of(sheetContext).pop();
    if (!mounted) {
      return;
    }

    ref.read(playerUiControllerProvider.notifier).selectEpisode(episode);
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
          currentEpisode: ref.read(playerUiControllerProvider).episodeNumber,
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
