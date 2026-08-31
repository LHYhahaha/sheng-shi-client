import 'dart:math' as math;

import 'package:drama_client/core/utils/compact_count_formatter.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../popup/domain/popup.dart';

class PlayerExitRecommendationDialog extends StatefulWidget {
  const PlayerExitRecommendationDialog({
    required this.recommendations,
    required this.onExit,
    required this.onPlay,
    this.onCardTap,
    super.key,
  });

  final List<PopupExitRecommendation> recommendations;
  final VoidCallback onExit;
  final ValueChanged<PopupExitRecommendation> onPlay;
  final ValueChanged<PopupExitRecommendation>? onCardTap;

  @override
  State<PlayerExitRecommendationDialog> createState() =>
      _PlayerExitRecommendationDialogState();
}

class _PlayerExitRecommendationDialogState
    extends State<PlayerExitRecommendationDialog> {
  static const _initialPage = 5000;
  static const _coverWidth = 234.0;
  static const _coverHeight = 349.0;
  static const _horizontalPadding = 16.0;
  static const _dialogHeightFactor = 0.75;
  static const _topPadding = 28.0;
  static const _bottomPadding = 24.0;
  static const _headerHeight = 28.0;
  static const _headerToCoverGap = 28.0;
  static const _detailsSectionHeight = 121.0;
  static const _buttonHeight = 40.0;

  late final PageController _pageController;
  late int _selectedPage;

  List<PopupExitRecommendation> get _items =>
      widget.recommendations.take(5).toList(growable: false);

  PopupExitRecommendation get _selectedItem =>
      _items[_selectedPage % _items.length];

  @override
  void initState() {
    super.initState();
    final itemCount = widget.recommendations.take(5).length;
    _selectedPage = itemCount == 0
        ? 0
        : _initialPage - (_initialPage % itemCount);
    _pageController = PageController(initialPage: _selectedPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }
    final screenSize = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final dialogHeight = screenSize.height * _dialogHeightFactor;
    final coverHeight = math
        .max(
          0.0,
          math.min(
            _coverHeight,
            dialogHeight -
                _topPadding -
                _bottomPadding -
                bottomInset -
                _headerHeight -
                _headerToCoverGap -
                _detailsSectionHeight -
                _buttonHeight,
          ),
        )
        .toDouble();
    final coverWidth = coverHeight * _coverWidth / _coverHeight;
    final item = _selectedItem;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const ValueKey('player_exit_recommendation_dialog'),
          width: double.infinity,
          height: dialogHeight,
          padding: EdgeInsets.only(
            top: _topPadding,
            bottom: _bottomPadding + bottomInset,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Text(
                context.l10n.popupDramaExitTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: _headerToCoverGap),
              const Spacer(),
              SizedBox(
                width: screenSize.width,
                height: coverHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _ExitRecommendationCarouselCards(
                        controller: _pageController,
                        selectedPage: _selectedPage,
                        items: _items,
                        coverWidth: coverWidth,
                        coverHeight: coverHeight,
                      ),
                    ),
                    Positioned.fill(
                      child: PageView.builder(
                        key: const ValueKey(
                          'player_exit_recommendation_carousel',
                        ),
                        controller: _pageController,
                        physics: const PageScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        onPageChanged: (page) {
                          setState(() {
                            _selectedPage = page;
                          });
                        },
                        itemBuilder: (context, index) {
                          final recommendation = _items[index % _items.length];
                          return Center(
                            child: Semantics(
                              button: true,
                              label: 'Play ${recommendation.title}',
                              child: GestureDetector(
                                key: index == _selectedPage
                                    ? const ValueKey(
                                        'player_exit_recommendation_cover_tap_target',
                                      )
                                    : ValueKey(
                                        'player_exit_recommendation_cover_tap_target_$index',
                                      ),
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    (widget.onCardTap ?? widget.onPlay)(
                                      recommendation,
                                    ),
                                child: SizedBox(
                                  width: coverWidth,
                                  height: coverHeight,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _detailsSectionHeight,
                child: Center(
                  child: SizedBox(
                    width: coverWidth,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          item.title,
                          key: ValueKey(
                            'player_exit_recommendation_title_${item.id}',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight(510),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RecommendationTags(item: item),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: SizedBox(
                  height: _buttonHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _ExitRecommendationButton(
                          key: const ValueKey(
                            'player_exit_recommendation_exit_button',
                          ),
                          backgroundColor: const Color(0xFF414141),
                          iconAssetPath: 'assets/images/player/exit.svg',
                          label: context.l10n.popupDramaExitActionExit,
                          onTap: widget.onExit,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _ExitRecommendationButton(
                          key: const ValueKey(
                            'player_exit_recommendation_play_button',
                          ),
                          backgroundColor: AppColors.primary,
                          iconAssetPath: 'assets/images/player/play_icon.svg',
                          label: context.l10n.popupDramaExitActionPlay,
                          onTap: () => widget.onPlay(item),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExitRecommendationCarouselCards extends StatelessWidget {
  const _ExitRecommendationCarouselCards({
    required this.controller,
    required this.selectedPage,
    required this.items,
    required this.coverWidth,
    required this.coverHeight,
  });

  final PageController controller;
  final int selectedPage;
  final List<PopupExitRecommendation> items;
  final double coverWidth;
  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF141414),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final currentPage = controller.hasClients
                ? controller.page ?? selectedPage.toDouble()
                : selectedPage.toDouble();
            final anchorPage = currentPage.floor();
            final visiblePages =
                <int>[
                  for (
                    var page = anchorPage - 2;
                    page <= anchorPage + 3;
                    page++
                  )
                    page,
                ]..sort((a, b) {
                  final bDistance = (currentPage - b).abs();
                  final aDistance = (currentPage - a).abs();
                  return bDistance.compareTo(aDistance);
                });

            return LayoutBuilder(
              builder: (context, constraints) {
                final centerX = constraints.maxWidth / 2;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final page in visiblePages)
                      _PositionedCarouselCover(
                        recommendation:
                            items[_positiveModulo(page, items.length)],
                        centerX:
                            centerX + (page - currentPage) * (coverWidth + 4),
                        distance: (currentPage - page).abs(),
                        coverWidth: coverWidth,
                        coverHeight: coverHeight,
                      ),
                    const _CarouselViewportShadowOverlay(),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static int _positiveModulo(int value, int divisor) {
    final result = value % divisor;
    return result < 0 ? result + divisor : result;
  }
}

class _PositionedCarouselCover extends StatelessWidget {
  const _PositionedCarouselCover({
    required this.recommendation,
    required this.centerX,
    required this.distance,
    required this.coverWidth,
    required this.coverHeight,
  });

  final PopupExitRecommendation recommendation;
  final double centerX;
  final double distance;
  final double coverWidth;
  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    final scale = (1 - distance * 0.28).clamp(0.82, 1.0);

    return Positioned(
      left: centerX - coverWidth / 2,
      top: 0,
      width: coverWidth,
      height: coverHeight,
      child: Transform.scale(
        scale: scale,
        child: _RecommendationCover(
          recommendation: recommendation,
          width: coverWidth,
          height: coverHeight,
        ),
      ),
    );
  }
}

class _CarouselViewportShadowOverlay extends StatelessWidget {
  const _CarouselViewportShadowOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF141414).withValues(alpha: 0.74),
                const Color(0xFF141414).withValues(alpha: 0.28),
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0),
                const Color(0xFF141414).withValues(alpha: 0.28),
                const Color(0xFF141414).withValues(alpha: 0.74),
              ],
              stops: const [0.0, 0.07, 0.18, 0.82, 0.93, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationCover extends StatelessWidget {
  const _RecommendationCover({
    required this.recommendation,
    required this.width,
    required this.height,
  });

  final PopupExitRecommendation recommendation;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AppCachedNetworkImage(
            imageUrl: recommendation.coverUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Row(
            children: [
              SvgPicture.asset(
                "assets/images/home/play_icon.svg",
                width: 8,
                height: 8,
              ),
              SizedBox(width: 2),
              Text(
                formatCompactCount(recommendation.playCount),
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0XFFE0E0E0),
                  fontWeight: FontWeight(510),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationTags extends StatelessWidget {
  const _RecommendationTags({required this.item});

  static const _gap = 6.0;

  final PopupExitRecommendation item;

  @override
  Widget build(BuildContext context) {
    final tags = item.tagsName;
    if (tags.isEmpty) {
      return const SizedBox();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleTags = _visibleTagsForWidth(
          context,
          tags,
          constraints.maxWidth,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final tag in visibleTags.indexed) ...[
              _RecommendationTag(label: tag.$2),
              if (tag.$1 != visibleTags.length - 1) const SizedBox(width: _gap),
            ],
          ],
        );
      },
    );
  }

  List<String> _visibleTagsForWidth(
    BuildContext context,
    List<String> tags,
    double maxWidth,
  ) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return const [];
    }

    final visibleTags = <String>[];
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(_RecommendationTag.textStyle);
    var usedWidth = 0.0;

    for (final tag in tags) {
      final painter = TextPainter(
        text: TextSpan(text: tag, style: style),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      final tagWidth =
          painter.width.ceilToDouble() +
          _RecommendationTag.horizontalPadding +
          1;
      final nextWidth = usedWidth + (visibleTags.isEmpty ? 0 : _gap) + tagWidth;
      if (nextWidth > maxWidth) {
        break;
      }
      visibleTags.add(tag);
      usedWidth = nextWidth;
    }

    return visibleTags;
  }
}

class _RecommendationTag extends StatelessWidget {
  const _RecommendationTag({required this.label});

  static const horizontalPadding = 16.0;
  static final textStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.8),
    fontSize: 9,
    fontWeight: FontWeight.w400,
  );

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );
  }
}

class _ExitRecommendationButton extends StatelessWidget {
  const _ExitRecommendationButton({
    required this.backgroundColor,
    required this.iconAssetPath,
    required this.label,
    required this.onTap,
    super.key,
  });

  final Color backgroundColor;
  final String iconAssetPath;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(iconAssetPath, width: 14, height: 14),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 18 / 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
