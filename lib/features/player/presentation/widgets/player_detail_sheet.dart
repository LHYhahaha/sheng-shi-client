import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_round_icon_button.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../domain/player_content.dart';

enum PlayerDetailTab { synopsis, episodes }

enum _DetailSheetMode { compact, expanded }

class PlayerDetailSheet extends StatefulWidget {
  const PlayerDetailSheet({
    required this.content,
    required this.initialTab,
    required this.currentEpisode,
    required this.onEpisodeSelected,
    super.key,
  });

  final PlayerContent content;
  final PlayerDetailTab initialTab;
  final int currentEpisode;
  final ValueChanged<PlayerEpisode> onEpisodeSelected;

  @override
  State<PlayerDetailSheet> createState() => _PlayerDetailSheetState();
}

class _PlayerDetailSheetState extends State<PlayerDetailSheet> {
  static const _sheetColor = Color(0xFF1F2022);
  static const _compactSize = 0.53;
  static const _expandedSize = 0.93;
  static const _minSize = 0.42;
  static const _maxSize = 0.95;
  static const _topChromeHeight = 78.0;

  late final DraggableScrollableController _sheetController;
  late PlayerDetailTab _selectedTab = widget.initialTab;
  late _DetailSheetMode _mode = _DetailSheetMode.compact;
  int _rangeStart = 1;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_syncModeFromSheetSize);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_syncModeFromSheetSize);
    _sheetController.dispose();
    super.dispose();
  }

  void _syncModeFromSheetSize() {
    if (!_sheetController.isAttached) {
      return;
    }
    final midpoint = (_compactSize + _expandedSize) / 2;
    final nextMode = _sheetController.size >= midpoint
        ? _DetailSheetMode.expanded
        : _DetailSheetMode.compact;
    if (nextMode != _mode) {
      setState(() => _mode = nextMode);
    }
  }

  Future<void> _setMode(_DetailSheetMode mode) async {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    if (!_sheetController.isAttached) {
      return;
    }
    final targetSize = mode == _DetailSheetMode.compact
        ? _compactSize
        : _expandedSize;
    await _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      controller: _sheetController,
      expand: false,
      initialChildSize: _compactSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_minSize, _compactSize, _expandedSize],
      builder: (context, scrollController) {
        return Material(
          color: _sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    _topChromeHeight + 8,
                    16,
                    bottomInset + 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(content: widget.content),
                      const SizedBox(height: 18),
                      _SegmentedControl(
                        selectedTab: _selectedTab,
                        onChanged: (tab) => setState(() => _selectedTab = tab),
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _selectedTab == PlayerDetailTab.synopsis
                            ? _SynopsisPanel(
                                key: const ValueKey('synopsis'),
                                content: widget.content,
                              )
                            : _EpisodesPanel(
                                key: const ValueKey('episodes'),
                                episodes: widget.content.episodes,
                                currentEpisode: widget.currentEpisode,
                                rangeStart: _rangeStart,
                                onRangeChanged: (value) {
                                  setState(() => _rangeStart = value);
                                },
                                onEpisodeSelected: widget.onEpisodeSelected,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: _topChromeHeight,
                height: 20,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_sheetColor, _sheetColor.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomInset + 40,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [_sheetColor, _sheetColor.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                key: const ValueKey('player_detail_sheet_top_chrome'),
                left: 0,
                right: 0,
                top: 0,
                height: _topChromeHeight,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: _sheetColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 8,
                        child: AppSheetHandle(),
                      ),
                      Positioned(
                        left: 16,
                        top: 22,
                        child: AppRoundIconButton(
                          key: _mode == _DetailSheetMode.compact
                              ? const ValueKey('player_detail_sheet_expand')
                              : const ValueKey('player_detail_sheet_shrink'),
                          icon: _mode == _DetailSheetMode.compact
                              ? Icons.open_in_full_rounded
                              : Icons.close_fullscreen_rounded,
                          onTap: () {
                            if (_mode == _DetailSheetMode.compact) {
                              unawaited(_setMode(_DetailSheetMode.expanded));
                            } else {
                              unawaited(_setMode(_DetailSheetMode.compact));
                            }
                          },
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 22,
                        child: AppRoundIconButton(
                          key: const ValueKey('player_detail_sheet_close'),
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.content});

  final PlayerContent content;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            content.posterAssetPath,
            width: 68,
            height: 91,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 20 / 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.viewCountLabel,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selectedTab, required this.onChanged});

  final PlayerDetailTab selectedTab;
  final ValueChanged<PlayerDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _Segment(
            label: context.l10n.playerSynopsis,
            selected: selectedTab == PlayerDetailTab.synopsis,
            onTap: () => onChanged(PlayerDetailTab.synopsis),
          ),
          _Segment(
            label: context.l10n.playerEpisodes,
            selected: selectedTab == PlayerDetailTab.episodes,
            onTap: () => onChanged(PlayerDetailTab.episodes),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              height: 18 / 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SynopsisPanel extends StatelessWidget {
  const _SynopsisPanel({required this.content, super.key});

  final PlayerContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: content.synopsis,
            children: [
              TextSpan(
                text: '...${context.l10n.playerMore}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.playerMoreLikeThis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 18 / 14,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: content.recommendations.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 16,
            childAspectRatio: 109 / 218,
          ),
          itemBuilder: (context, index) {
            return _RecommendationCard(
              recommendation: content.recommendations[index],
            );
          },
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final PlayerRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AspectRatio(
            aspectRatio: 109 / 147,
            child: Image.asset(
              recommendation.coverAssetPath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          recommendation.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          recommendation.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
      ],
    );
  }
}

class _EpisodesPanel extends StatelessWidget {
  const _EpisodesPanel({
    required this.episodes,
    required this.currentEpisode,
    required this.rangeStart,
    required this.onRangeChanged,
    required this.onEpisodeSelected,
    super.key,
  });

  final List<PlayerEpisode> episodes;
  final int currentEpisode;
  final int rangeStart;
  final ValueChanged<int> onRangeChanged;
  final ValueChanged<PlayerEpisode> onEpisodeSelected;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return Center(
        child: Text(
          context.l10n.playerFeedEmpty,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            height: 18 / 14,
          ),
        ),
      );
    }

    final visibleEpisodes = episodes
        .where((episode) {
          return episode.number >= rangeStart &&
              episode.number < rangeStart + 30;
        })
        .toList(growable: false);

    final maxEpisodeNumber = episodes.isNotEmpty
        ? episodes.map((e) => e.number).reduce((a, b) => a > b ? a : b)
        : 0;
    final showSecondRange = maxEpisodeNumber > 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _RangeButton(
              label: '1-30',
              selected: rangeStart == 1,
              onTap: () => onRangeChanged(1),
            ),
            if (showSecondRange) ...[
              const SizedBox(width: 20),
              _RangeButton(
                label: '31-${(maxEpisodeNumber ~/ 30 + 1) * 30}',
                selected: rangeStart == 31,
                onTap: () => onRangeChanged(31),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (visibleEpisodes.isEmpty)
          Center(
            child: Text(
              context.l10n.playerFeedEmpty,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                height: 18 / 14,
              ),
            ),
          )
        else
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: visibleEpisodes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 66 / 54,
            ),
            itemBuilder: (context, index) {
              final episode = visibleEpisodes[index];
              return _EpisodeTile(
                episode: episode,
                selected: episode.number == currentEpisode,
                onTap: () => onEpisodeSelected(episode),
              );
            },
          ),
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 21 / 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.selected,
    required this.onTap,
  });

  final PlayerEpisode episode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF494A50)
                    : const Color(0xFF313136),
                borderRadius: BorderRadius.circular(8),
              ),
              child: selected
                  ? const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 24,
                    )
                  : Text(
                      episode.number.toString(),
                      style: TextStyle(
                        color: episode.isLocked || episode.isUnavailable
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
            ),
          ),
          if (episode.isLocked)
            Positioned(
              right: 4,
              top: 3,
              child: Icon(
                Icons.lock_rounded,
                color: Colors.white.withValues(alpha: 0.28),
                size: 12,
              ),
            ),
          if (episode.isUnavailable)
            Positioned(
              right: 4,
              top: 3,
              child: Icon(
                Icons.block_rounded,
                color: Colors.white.withValues(alpha: 0.28),
                size: 12,
              ),
            ),
          if (episode.number == 10)
            const Positioned(right: 0, top: 0, child: _GiftBadge()),
        ],
      ),
    );
  }
}

class _GiftBadge extends StatelessWidget {
  const _GiftBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      ),
      child: const Icon(
        Icons.local_fire_department,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}
