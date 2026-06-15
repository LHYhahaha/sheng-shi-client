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
                                totalEpisodes: widget.content.episodeTotal,
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
                      // Positioned(
                      //   left: 16,
                      //   top: 22,
                      //   child: AppRoundIconButton(
                      //     key: _mode == _DetailSheetMode.compact
                      //         ? const ValueKey('player_detail_sheet_expand')
                      //         : const ValueKey('player_detail_sheet_shrink'),
                      //     icon: _mode == _DetailSheetMode.compact
                      //         ? Icons.open_in_full_rounded
                      //         : Icons.close_fullscreen_rounded,
                      //     onTap: () {
                      //       if (_mode == _DetailSheetMode.compact) {
                      //         unawaited(_setMode(_DetailSheetMode.expanded));
                      //       } else {
                      //         unawaited(_setMode(_DetailSheetMode.compact));
                      //       }
                      //     },
                      //   ),
                      // ),
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

  Widget _buildCoverImage() {
    final coverUrl = content.coverUrl;
    final posterPath = content.posterAssetPath;

    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Image.network(
        coverUrl,
        width: 68,
        height: 91,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            posterPath,
            width: 68,
            height: 91,
            fit: BoxFit.cover,
          );
        },
      );
    }

    return Image.asset(
      posterPath,
      width: 68,
      height: 91,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _buildCoverImage(),
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

class _SynopsisPanel extends StatefulWidget {
  const _SynopsisPanel({required this.content, super.key});

  final PlayerContent content;

  @override
  State<_SynopsisPanel> createState() => _SynopsisPanelState();
}

class _SynopsisPanelState extends State<_SynopsisPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final synopsis = widget.content.synopsis;
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.42),
      fontSize: 12,
      height: 16 / 12,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 使用 LayoutBuilder 动态检测文本是否溢出
        LayoutBuilder(
          builder: (context, constraints) {
            // 使用 TextPainter 检测文本是否超过三行
            final textPainter = TextPainter(
              text: TextSpan(text: synopsis, style: textStyle),
              maxLines: 3,
              textDirection: TextDirection.ltr,
            );
            textPainter.layout(maxWidth: constraints.maxWidth);
            
            // 计算完整文本的高度
            final fullTextPainter = TextPainter(
              text: TextSpan(text: synopsis, style: textStyle),
              textDirection: TextDirection.ltr,
            );
            fullTextPainter.layout(maxWidth: constraints.maxWidth);
            
            // 如果完整文本高度大于三行文本高度，说明文本溢出了
            final isOverflowing = fullTextPainter.height > textPainter.height + 0.1;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  synopsis,
                  maxLines: _isExpanded ? null : 3,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                  style: textStyle,
                ),
                if (isOverflowing && !_isExpanded)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = true;
                      });
                    },
                    child: Text(
                      ' ${context.l10n.playerMore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_isExpanded)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = false;
                      });
                    },
                    child: const Text(
                      ' Less...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            );
          },
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
          itemCount: widget.content.recommendations.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 16,
            childAspectRatio: 109 / 218,
          ),
          itemBuilder: (context, index) {
            return _RecommendationCard(
              recommendation: widget.content.recommendations[index],
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
            child: _buildCoverImage(),
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

  Widget _buildCoverImage() {
    final path = recommendation.coverAssetPath;
    
    // 判断是否是网络 URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          );
        },
      );
    }
    
    // 本地 asset
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[800],
          child: const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        );
      },
    );
  }
}

class _EpisodesPanel extends StatefulWidget {
  const _EpisodesPanel({
    required this.episodes,
    required this.currentEpisode,
    required this.rangeStart,
    required this.onRangeChanged,
    required this.onEpisodeSelected,
    required this.totalEpisodes,
    super.key,
  });

  final List<PlayerEpisode> episodes;
  final int currentEpisode;
  final int rangeStart;
  final ValueChanged<int> onRangeChanged;
  final ValueChanged<PlayerEpisode> onEpisodeSelected;
  final int totalEpisodes;

  @override
  State<_EpisodesPanel> createState() => _EpisodesPanelState();
}

class _EpisodesPanelState extends State<_EpisodesPanel> {
  late final ScrollController _rangeScrollController;
  bool _hasScrolledToSelected = false;

  @override
  void initState() {
    super.initState();
    _rangeScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedRange();
    });
  }

  @override
  void didUpdateWidget(_EpisodesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rangeStart != widget.rangeStart) {
      _hasScrolledToSelected = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedRange();
      });
    }
  }

  void _scrollToSelectedRange() {
    if (_hasScrolledToSelected || !_rangeScrollController.hasClients) {
      return;
    }

    final ranges = _generateRanges();
    final selectedIndex = ranges.indexWhere(
      (range) => range.start == widget.rangeStart,
    );

    if (selectedIndex < 0) {
      return;
    }

    // 计算选中项的位置
    const itemWidth = 60.0; // 估算每个range button的宽度
    const separatorWidth = 20.0;
    final targetOffset = selectedIndex * (itemWidth + separatorWidth);
    final maxOffset = _rangeScrollController.position.maxScrollExtent;

    _rangeScrollController.animateTo(
      targetOffset.clamp(0.0, maxOffset),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    _hasScrolledToSelected = true;
  }

  @override
  void dispose() {
    _rangeScrollController.dispose();
    super.dispose();
  }

  /// 生成所有的 episode range tabs
  List<({int start, int end})> _generateRanges() {
    if (widget.totalEpisodes <= 0) {
      return [];
    }

    final ranges = <({int start, int end})>[];
    int start = 1;
    while (start <= widget.totalEpisodes) {
      final end = (start + 29).clamp(start, widget.totalEpisodes);
      ranges.add((start: start, end: end));
      start = end + 1;
    }
    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.episodes.isEmpty) {
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

    final ranges = _generateRanges();
    final visibleEpisodes = widget.episodes
        .where((episode) {
          return episode.number >= widget.rangeStart &&
              episode.number < widget.rangeStart + 30;
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            controller: _rangeScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: ranges.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              return _RangeButton(
                label: '${ranges[index].start}-${ranges[index].end}',
                selected: widget.rangeStart == ranges[index].start,
                onTap: () => widget.onRangeChanged(ranges[index].start),
              );
            },
          ),
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
                selected: episode.number == widget.currentEpisode,
                onTap: () => widget.onEpisodeSelected(episode),
                currentEpisode: widget.currentEpisode,
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
        child: Center(
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
    required this.currentEpisode,
  });

  final PlayerEpisode episode;
  final bool selected;
  final VoidCallback onTap;
  final int currentEpisode;

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
          if (episode.isLocked && episode.number == currentEpisode + 1)
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
        Icons.lock_rounded,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}
