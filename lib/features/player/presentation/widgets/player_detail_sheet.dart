import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:readmore/readmore.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../../../shared/widgets/app_round_icon_button.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../data/local/player_episode_unlock_cache.dart';
import '../../domain/player_content.dart';

enum PlayerDetailTab { synopsis, episodes }

enum _DetailSheetMode { compact, expanded }

List<({int start, int end})> _episodeRanges(int totalEpisodes) {
  final ranges = <({int start, int end})>[];
  for (var start = 1; start <= totalEpisodes; start += 30) {
    ranges.add((start: start, end: (start + 29).clamp(start, totalEpisodes)));
  }
  return ranges;
}

class PlayerDetailSheet extends StatefulWidget {
  const PlayerDetailSheet({
    required this.content,
    required this.initialTab,
    required this.currentEpisode,
    this.currentEpisodeId,
    required this.onEpisodeSelected,
    required this.onRecommendationSelected,
    this.recommendationsFuture,
    super.key,
  });

  final PlayerContent content;
  final PlayerDetailTab initialTab;
  final int currentEpisode;
  final String? currentEpisodeId;
  final ValueChanged<PlayerEpisode> onEpisodeSelected;
  final void Function(PlayerRecommendation recommendation, int position)
  onRecommendationSelected;
  final Future<List<PlayerRecommendation>>? recommendationsFuture;

  @override
  State<PlayerDetailSheet> createState() => _PlayerDetailSheetState();
}

class _PlayerDetailSheetState extends State<PlayerDetailSheet> {
  static const _sheetColor = Color(0xFF1F2022);
  static const _compactSize = 0.53;
  static const _expandedSize = 0.93;
  static const _minSize = 0.42;
  static const _maxSize = 0.95;
  static const _topChromeHeight = 66.0;
  static const _contentTopInset = _topChromeHeight + 8;
  static const _episodeRangeHeight = 48.0;

  late final DraggableScrollableController _sheetController;
  late PlayerDetailTab _selectedTab = widget.initialTab;
  late _DetailSheetMode _mode = _DetailSheetMode.compact;
  final _episodesPanelKey = GlobalKey<_EpisodesPanelState>();
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

  Widget _buildHeaderAndTabs() {
    return Container(
      color: _sheetColor,
      padding: EdgeInsets.fromLTRB(16.w, _contentTopInset.w, 16.w, 18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(content: widget.content),
          SizedBox(height: 18.w),
          _SegmentedControl(
            selectedTab: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeRangeSelector() {
    final ranges = _episodeRanges(widget.content.episodeTotal);

    return Container(
      color: _sheetColor,
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.w),
      child: SizedBox(
        height: 36.w,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ranges.length,
          separatorBuilder: (context, index) => SizedBox(width: 20.w),
          itemBuilder: (context, index) {
            final range = ranges[index];
            return _RangeButton(
              label: '${range.start}-${range.end}',
              selected: _rangeStart == range.start,
              onTap: () =>
                  _episodesPanelKey.currentState?._selectRange(range.start),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScrollableContent({
    required ScrollController scrollController,
    required double bottomInset,
  }) {
    final pinHeaders = _mode == _DetailSheetMode.expanded;
    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPersistentHeader(
          pinned: pinHeaders,
          delegate: _FixedExtentHeaderDelegate(
            extent:
                _contentTopInset.w +
                _Header.preferredHeight(context, widget.content) +
                18.w +
                _SegmentedControl.preferredHeight(context) +
                18.w,
            child: _buildHeaderAndTabs(),
          ),
        ),
        if (_selectedTab == PlayerDetailTab.episodes) ...[
          SliverPersistentHeader(
            pinned: pinHeaders,
            delegate: _FixedExtentHeaderDelegate(
              extent: _episodeRangeHeight.w,
              child: _buildEpisodeRangeSelector(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomInset + 32.w),
            sliver: SliverToBoxAdapter(
              child: _EpisodesPanel(
                key: _episodesPanelKey,
                dramaId: widget.content.id,
                episodes: widget.content.episodes,
                currentEpisode: widget.currentEpisode,
                currentEpisodeId: widget.currentEpisodeId,
                sheetScrollController: scrollController,
                rangeStart: _rangeStart,
                onRangeChanged: (value) => setState(() => _rangeStart = value),
                onEpisodeSelected: widget.onEpisodeSelected,
                totalEpisodes: widget.content.episodeTotal,
              ),
            ),
          ),
        ] else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomInset + 32.w),
            sliver: SliverToBoxAdapter(
              child: _SynopsisPanel(
                content: widget.content,
                onRecommendationSelected: widget.onRecommendationSelected,
                recommendationsFuture: widget.recommendationsFuture,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      key: const ValueKey('player_detail_sheet_draggable'),
      controller: _sheetController,
      expand: false,
      initialChildSize: _compactSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_minSize, _compactSize, _expandedSize],
      builder: (context, scrollController) {
        return Material(
          key: const ValueKey('player_detail_sheet_surface'),
          color: _sheetColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.w)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _buildScrollableContent(
                  scrollController: scrollController,
                  bottomInset: bottomInset,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: _topChromeHeight.w,
                height: 20.w,
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
                height: bottomInset + 40.w,
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
                height: _topChromeHeight.w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _sheetColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28.w),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 8.w,
                        child: const AppSheetHandle(),
                      ),
                      Positioned(
                        right: 16.w,
                        top: 18.w,
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

class _FixedExtentHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FixedExtentHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_FixedExtentHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}

class _Header extends StatelessWidget {
  const _Header({required this.content});

  final PlayerContent content;

  static TextStyle _titleStyle(BuildContext context) => TextStyle(
    color: Colors.white,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    height: 20 / 16,
  );

  static TextStyle _viewCountStyle(BuildContext context) => TextStyle(
    color: AppColors.primary,
    fontSize: 12.sp,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  static double preferredHeight(BuildContext context, PlayerContent content) {
    final contentWidth = MediaQuery.sizeOf(context).width - 32.w;
    final textWidth = (contentWidth - 68.w - 12.w)
        .clamp(0.0, double.infinity)
        .toDouble();
    final textScaler = MediaQuery.textScalerOf(context);
    final titlePainter = TextPainter(
      text: TextSpan(text: content.title, style: _titleStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: textWidth);
    final viewCountPainter = TextPainter(
      text: TextSpan(
        text: '${content.viewCountLabel} ${context.l10n.episodeModalViews}',
        style: _viewCountStyle(context),
      ),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    )..layout(maxWidth: textWidth);

    return [
      91.w,
      titlePainter.height + 4.w + viewCountPainter.height,
    ].reduce((largest, height) => largest > height ? largest : height);
  }

  Widget _buildCoverImage() {
    final coverUrl = content.coverUrl;

    if (coverUrl != null && coverUrl.isNotEmpty) {
      return AppCachedNetworkImage(
        imageUrl: coverUrl,
        width: 68.w,
        height: 91.w,
        fit: BoxFit.cover,
      );
    }

    return SizedBox(width: 68.w, height: 91.w);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: _buildCoverImage(),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle(context),
              ),
              SizedBox(height: 4.w),
              Text(
                "${content.viewCountLabel} ${context.l10n.episodeModalViews}",
                style: _viewCountStyle(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.selectedTab, required this.onChanged});

  static const _verticalPadding = 4.0;
  static const _segmentVerticalPadding = 5.0;

  static TextStyle _labelStyle(BuildContext context) =>
      TextStyle(color: Colors.white, fontSize: 14.sp, height: 18 / 14);

  static double preferredHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: _labelStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.height +
        _segmentVerticalPadding.w * 2 +
        _verticalPadding.w * 2;
  }

  final PlayerDetailTab selectedTab;
  final ValueChanged<PlayerDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_verticalPadding.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100.w),
      ),
      child: Row(
        children: [
          _Segment(
            label: context.l10n.playerSynopsis,
            selected: selectedTab == PlayerDetailTab.synopsis,
            onTap: () => onChanged(PlayerDetailTab.synopsis),
          ),
          _Segment(
            label: context.l10n.episodeModalEpisodes,
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
          padding: EdgeInsets.symmetric(
            vertical: _SegmentedControl._segmentVerticalPadding.w,
          ),
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20.w),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
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
  const _SynopsisPanel({
    required this.content,
    required this.onRecommendationSelected,
    this.recommendationsFuture,
  });

  final PlayerContent content;
  final void Function(PlayerRecommendation recommendation, int position)
  onRecommendationSelected;
  final Future<List<PlayerRecommendation>>? recommendationsFuture;

  @override
  State<_SynopsisPanel> createState() => _SynopsisPanelState();
}

class _SynopsisPanelState extends State<_SynopsisPanel> {
  Future<List<PlayerRecommendation>>? _cachedFuture;

  @override
  void didUpdateWidget(_SynopsisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recommendationsFuture != oldWidget.recommendationsFuture) {
      _cachedFuture = widget.recommendationsFuture;
    }
  }

  @override
  Widget build(BuildContext context) {
    final synopsis = widget.content.synopsis;
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.4),
      fontSize: 12.sp,
      height: 16 / 12,
      fontWeight: FontWeight.normal,
    );

    // 确定要使用的 future
    final future = _cachedFuture ?? widget.recommendationsFuture;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReadMoreText(
          synopsis,
          trimLines: 3,
          trimMode: TrimMode.Line,
          trimCollapsedText: context.l10n.playerMore,
          trimExpandedText: context.l10n.playerLess,
          style: textStyle,
          lessStyle: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
          ),
          moreStyle: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 24.w),
        Text(
          context.l10n.playerMoreLikeThis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            height: 18 / 14,
          ),
        ),
        SizedBox(height: 10.w),
        // 根据是否有 future 来决定使用异步加载还是同步显示
        if (future != null)
          // 异步加载推荐列表
          FutureBuilder<List<PlayerRecommendation>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // 加载中 - 显示 loading 指示器（跟首页一样）
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.w),
                    child: AppPegTopLoader(),
                  ),
                );
              }

              final recommendations = snapshot.data ?? [];
              if (recommendations.isEmpty) {
                // 加载完成但为空 - 显示空状态
                return const _RecommendationEmptyState();
              }

              // 加载完成且有数据 - 显示推荐列表
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: recommendations.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8.w,
                  mainAxisSpacing: 16.w,
                  childAspectRatio: 109 / 218,
                ),
                itemBuilder: (context, index) {
                  final recommendation = recommendations[index];
                  return _RecommendationCard(
                    recommendation: recommendation,
                    onTap: () {
                      widget.onRecommendationSelected(
                        recommendation,
                        index + 1,
                      );
                    },
                  );
                },
              );
            },
          )
        else
        // 同步显示推荐列表
        if (widget.content.recommendations.isEmpty)
          // 为空 - 显示空状态
          const _RecommendationEmptyState()
        else
          // 有数据 - 显示推荐列表
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: widget.content.recommendations.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 16.w,
              childAspectRatio: 109 / 218,
            ),
            itemBuilder: (context, index) {
              final recommendation = widget.content.recommendations[index];
              return _RecommendationCard(
                recommendation: recommendation,
                onTap: () {
                  widget.onRecommendationSelected(recommendation, index + 1);
                },
              );
            },
          ),
      ],
    );
  }
}

class _RecommendationEmptyState extends StatelessWidget {
  const _RecommendationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32.w),
        child: AppEmptyState(message: context.l10n.recommendTabEmptyNoContent),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation, this.onTap});

  final PlayerRecommendation recommendation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: AspectRatio(aspectRatio: 109 / 147, child: _buildCoverImage()),
        ),
        SizedBox(height: 4.w),
        Text(
          recommendation.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            height: 16 / 12,
          ),
        ),
        SizedBox(height: 6.w),
        Text(
          recommendation.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.sp,
            height: 16 / 12,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildCoverImage() {
    final path = recommendation.coverAssetPath;

    // 判断是否是网络 URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return AppCachedNetworkImage(imageUrl: path, fit: BoxFit.cover);
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
    required this.dramaId,
    required this.episodes,
    required this.currentEpisode,
    required this.currentEpisodeId,
    required this.sheetScrollController,
    required this.rangeStart,
    required this.onRangeChanged,
    required this.onEpisodeSelected,
    required this.totalEpisodes,
    super.key,
  });

  final String dramaId;
  final List<PlayerEpisode> episodes;
  final int currentEpisode;
  final String? currentEpisodeId;
  final ScrollController sheetScrollController;
  final int rangeStart;
  final ValueChanged<int> onRangeChanged;
  final ValueChanged<PlayerEpisode> onEpisodeSelected;
  final int totalEpisodes;

  @override
  State<_EpisodesPanel> createState() => _EpisodesPanelState();
}

class _EpisodesPanelState extends State<_EpisodesPanel> {
  late final ScrollController _rangeScrollController;
  final _episodeGridKey = GlobalKey();
  bool _hasScrolledToSelected = false;
  bool _isSelectingRange = false;
  bool _isClampingScroll = false;
  bool _isSpacerUpdateScheduled = false;
  double _bottomSpacerHeight = 0;

  @override
  void initState() {
    super.initState();
    _rangeScrollController = ScrollController();
    widget.sheetScrollController.addListener(_syncRangeWithEpisodeList);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedRange();
      _ensureLastRangeCanLead();
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
    if (oldWidget.sheetScrollController != widget.sheetScrollController) {
      oldWidget.sheetScrollController.removeListener(_syncRangeWithEpisodeList);
      widget.sheetScrollController.addListener(_syncRangeWithEpisodeList);
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
    final itemWidth = 60.w; // 估算每个range button的宽度
    final separatorWidth = 20.w;
    final targetOffset = selectedIndex * (itemWidth + separatorWidth);
    final maxOffset = _rangeScrollController.position.maxScrollExtent;

    _rangeScrollController.animateTo(
      targetOffset.clamp(0.0, maxOffset),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    _hasScrolledToSelected = true;
  }

  void _syncRangeWithEpisodeList() {
    if (_isSelectingRange ||
        !widget.sheetScrollController.hasClients ||
        widget.episodes.isEmpty) {
      return;
    }

    final gridContext = _episodeGridKey.currentContext;
    final gridBox = gridContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) {
      return;
    }

    // DraggableScrollableSheet changes the viewport height while expanding.
    // Recalculate after that frame so the final range can still reach row one.
    _scheduleLastRangeSpacerUpdate();

    final maximumOffset = _maximumEpisodeListOffset(gridBox);
    if (!_isClampingScroll &&
        widget.sheetScrollController.offset > maximumOffset + 0.5) {
      _isClampingScroll = true;
      widget.sheetScrollController.jumpTo(maximumOffset);
      _isClampingScroll = false;
      return;
    }

    final firstVisibleIndex = _firstVisibleEpisodeIndex(gridBox: gridBox);
    final episodeNumber = widget.episodes[firstVisibleIndex].number;
    final visibleRangeStart = ((episodeNumber - 1) ~/ 30) * 30 + 1;

    if (visibleRangeStart != widget.rangeStart) {
      widget.onRangeChanged(visibleRangeStart);
    }
  }

  void _selectRange(int rangeStart) {
    widget.onRangeChanged(rangeStart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gridContext = _episodeGridKey.currentContext;
      final gridBox = gridContext?.findRenderObject() as RenderBox?;
      if (!mounted ||
          gridBox == null ||
          !widget.sheetScrollController.hasClients) {
        return;
      }

      final targetIndex = widget.episodes.indexWhere(
        (episode) => episode.number >= rangeStart,
      );
      if (targetIndex < 0) {
        return;
      }

      final targetRow = targetIndex ~/ 5;
      final targetOffset = targetRow * _episodeRowStride(gridBox);
      _isSelectingRange = true;
      widget.sheetScrollController
          .animateTo(
            targetOffset
                .clamp(
                  0.0,
                  widget.sheetScrollController.position.maxScrollExtent,
                )
                .toDouble(),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (!mounted) {
              return;
            }
            _isSelectingRange = false;
            widget.onRangeChanged(rangeStart);
          });
    });
  }

  double _episodeRowStride(RenderBox gridBox) {
    const crossAxisCount = 5;
    final spacing = 4.w;
    const childAspectRatio = 66 / 54;
    final childWidth =
        (gridBox.size.width - spacing * (crossAxisCount - 1)) / crossAxisCount;
    return childWidth / childAspectRatio + spacing;
  }

  double _maximumEpisodeListOffset(RenderBox gridBox) {
    final lastRangeStart = ((widget.totalEpisodes - 1) ~/ 30) * 30 + 1;
    final firstIndexOfLastRange = widget.episodes.indexWhere(
      (episode) => episode.number >= lastRangeStart,
    );
    if (firstIndexOfLastRange < 0) {
      return 0;
    }
    return firstIndexOfLastRange ~/ 5 * _episodeRowStride(gridBox);
  }

  void _ensureLastRangeCanLead() {
    if (!mounted || !widget.sheetScrollController.hasClients) {
      return;
    }

    final gridContext = _episodeGridKey.currentContext;
    final gridBox = gridContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) {
      return;
    }

    final missingScrollExtent =
        (_maximumEpisodeListOffset(gridBox) -
                widget.sheetScrollController.position.maxScrollExtent)
            .clamp(0.0, double.infinity)
            .toDouble();
    if (missingScrollExtent > 0.5) {
      setState(() => _bottomSpacerHeight += missingScrollExtent);
    }
  }

  void _scheduleLastRangeSpacerUpdate() {
    if (_isSpacerUpdateScheduled) {
      return;
    }
    _isSpacerUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isSpacerUpdateScheduled = false;
      _ensureLastRangeCanLead();
    });
  }

  int _firstVisibleEpisodeIndex({required RenderBox gridBox}) {
    final row =
        ((widget.sheetScrollController.offset / _episodeRowStride(gridBox)) +
                0.01)
            .floor()
            .clamp(0, (widget.episodes.length - 1) ~/ 5);
    return (row * 5).clamp(0, widget.episodes.length - 1).toInt();
  }

  @override
  void dispose() {
    widget.sheetScrollController.removeListener(_syncRangeWithEpisodeList);
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
          context.l10n.playerNoEpisodes,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14.sp,
            height: 18 / 14,
          ),
        ),
      );
    }

    _scheduleLastRangeSpacerUpdate();

    return Column(
      children: [
        GridView.builder(
          key: _episodeGridKey,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: 24.w),
          itemCount: widget.episodes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.w,
            childAspectRatio: 66 / 54,
          ),
          itemBuilder: (context, index) {
            final episode = widget.episodes[index];
            final hasCurrentEpisodeId =
                widget.currentEpisodeId?.isNotEmpty ?? false;
            final selected = hasCurrentEpisodeId
                ? episode.id == widget.currentEpisodeId
                : episode.number == widget.currentEpisode;
            return _EpisodeTile(
              dramaId: widget.dramaId,
              episode: episode,
              selected: selected,
              onTap: () => widget.onEpisodeSelected(episode),
              currentEpisode: widget.currentEpisode,
            );
          },
        ),
        SizedBox(height: _bottomSpacerHeight),
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
        height: 36.w,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 14.sp,
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
    required this.dramaId,
    required this.episode,
    required this.selected,
    required this.onTap,
    required this.currentEpisode,
  });

  final String dramaId;
  final PlayerEpisode episode;
  final bool selected;
  final VoidCallback onTap;
  final int currentEpisode;

  /// 检查剧集是否已解锁（优先使用缓存）。
  bool get isEffectivelyUnlocked {
    return PlayerEpisodeUnlockCache.isEpisodeUnlocked(
      dramaId,
      episode.id,
      episode.isLocked,
    );
  }

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
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: selected
                  ? Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 24.w,
                    )
                  : Text(
                      episode.number.toString(),
                      style: TextStyle(
                        color: !isEffectivelyUnlocked || episode.isUnavailable
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
            ),
          ),
          if (!isEffectivelyUnlocked)
            Positioned(
              right: 4.w,
              top: 3.w,
              child: Icon(
                Icons.lock_rounded,
                color: Colors.white.withValues(alpha: 0.28),
                size: 12.w,
              ),
            ),
          if (episode.isUnavailable)
            Positioned(
              right: 4.w,
              top: 3.w,
              child: Icon(
                Icons.block_rounded,
                color: Colors.white.withValues(alpha: 0.28),
                size: 12.w,
              ),
            ),
          if (!isEffectivelyUnlocked && episode.number == currentEpisode + 1)
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
      width: 18.w,
      height: 18.w,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8.r),
          bottomLeft: Radius.circular(8.r),
        ),
      ),
      child: Icon(Icons.lock_rounded, color: Colors.white, size: 12.w),
    );
  }
}
