import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
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
  late int _episodeNumber = int.tryParse(widget.episodeId) ?? 1;
  bool _isPlaying = false;
  bool _showsPaywall = false;
  bool _memberPaywall = false;

  @override
  Widget build(BuildContext context) {
    final contentState = ref.watch(_playerContentProvider(widget.dramaId));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: PopScope(
        canPop: !_showsPaywall,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || !_showsPaywall) {
            return;
          }

          setState(() {
            _showsPaywall = false;
            _memberPaywall = false;
          });
        },
        child: contentState.when(
          data: (content) => Stack(
            children: [
              Positioned.fill(
                child: PlayerChrome(
                  content: content,
                  episodeNumber: _episodeNumber,
                  isPlaying: _isPlaying,
                  onTogglePlay: () {
                    setState(() => _isPlaying = !_isPlaying);
                  },
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
                  onUnlockTap: () {
                    setState(() {
                      _showsPaywall = true;
                      _memberPaywall = true;
                    });
                  },
                ),
              ),
              if (_showsPaywall)
                PlayerPaywallOverlay(
                  label: _memberPaywall
                      ? context.l10n.playerMemberUnlock
                      : context.l10n.playerUnlockNow,
                  onTap: _showUnlockSheet,
                  onDismiss: () {
                    setState(() {
                      _showsPaywall = false;
                      _memberPaywall = false;
                    });
                  },
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

  void _showPaywallForEpisode(PlayerEpisode episode) {
    setState(() {
      _episodeNumber = episode.number;
      _showsPaywall = true;
      _memberPaywall = false;
      _isPlaying = false;
    });
  }

  void _playEpisode(PlayerEpisode episode) {
    setState(() {
      _episodeNumber = episode.number;
      _showsPaywall = false;
      _memberPaywall = false;
      _isPlaying = true;
    });
  }

  void _closeSheetAndSelectEpisode(
    BuildContext sheetContext,
    PlayerEpisode episode,
  ) {
    Navigator.of(sheetContext).pop();
    if (!mounted) {
      return;
    }

    if (episode.isLocked) {
      _showPaywallForEpisode(episode);
      return;
    }

    _playEpisode(episode);
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
          currentEpisode: _episodeNumber,
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

    setState(() {
      _showsPaywall = false;
      _memberPaywall = false;
      _isPlaying = true;
    });
  }
}
