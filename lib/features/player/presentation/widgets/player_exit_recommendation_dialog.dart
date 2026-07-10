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
    super.key,
  });

  final List<PopupExitRecommendation> recommendations;
  final VoidCallback onExit;
  final ValueChanged<PopupExitRecommendation> onPlay;

  @override
  State<PlayerExitRecommendationDialog> createState() =>
      _PlayerExitRecommendationDialogState();
}

class _PlayerExitRecommendationDialogState
    extends State<PlayerExitRecommendationDialog> {
  static const _initialPage = 5000;
  static const _coverWidth = 234.0;
  static const _coverHeight = 349.0;
  static const _horizontalPadding = 12.0;

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
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final item = _selectedItem;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const ValueKey('player_exit_recommendation_dialog'),
          width: double.infinity,
          padding: EdgeInsets.only(top: 28, bottom: 32 + bottomPadding),
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'More Like This',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 20 / 15,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  height: _coverHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _ExitRecommendationCarouselCards(
                          controller: _pageController,
                          selectedPage: _selectedPage,
                          items: _items,
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
                            return const SizedBox.expand();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  child: Text(
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
                      height: 20 / 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  child: _RecommendationTags(item: item),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ExitRecommendationButton(
                          key: const ValueKey(
                            'player_exit_recommendation_exit_button',
                          ),
                          backgroundColor: const Color(0xFF4A4A4A),
                          iconAssetPath: 'assets/images/player/exit.svg',
                          label: 'Exit',
                          onTap: widget.onExit,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: _ExitRecommendationButton(
                          key: const ValueKey(
                            'player_exit_recommendation_play_button',
                          ),
                          backgroundColor: AppColors.primary,
                          iconAssetPath: 'assets/images/player/play_icon.svg',
                          label: 'Play',
                          onTap: () => widget.onPlay(item),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  });

  static const _sideOffset = 238.0;

  final PageController controller;
  final int selectedPage;
  final List<PopupExitRecommendation> items;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final currentPage = controller.hasClients
              ? controller.page ?? selectedPage.toDouble()
              : selectedPage.toDouble();
          final anchorPage = currentPage.floor();
          final visiblePages =
              <int>[
                for (var page = anchorPage - 2; page <= anchorPage + 3; page++)
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
                      centerX: centerX + (page - currentPage) * _sideOffset,
                      distance: (currentPage - page).abs(),
                    ),
                  const _CarouselViewportShadowOverlay(),
                ],
              );
            },
          );
        },
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
  });

  final PopupExitRecommendation recommendation;
  final double centerX;
  final double distance;

  @override
  Widget build(BuildContext context) {
    final scale = (1 - distance * 0.28).clamp(0.82, 1.0);

    return Positioned(
      left: centerX - _PlayerExitRecommendationDialogState._coverWidth / 2,
      top: 0,
      width: _PlayerExitRecommendationDialogState._coverWidth,
      height: _PlayerExitRecommendationDialogState._coverHeight,
      child: Transform.scale(
        scale: scale,
        child: _RecommendationCover(recommendation: recommendation),
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
                Colors.black.withValues(alpha: 0.74),
                Colors.black.withValues(alpha: 0.28),
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0),
                Colors.black.withValues(alpha: 0.28),
                Colors.black.withValues(alpha: 0.74),
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
  const _RecommendationCover({required this.recommendation});

  final PopupExitRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AppCachedNetworkImage(
        imageUrl: recommendation.coverUrl,
        width: _PlayerExitRecommendationDialogState._coverWidth,
        height: _PlayerExitRecommendationDialogState._coverHeight,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}

class _RecommendationTags extends StatelessWidget {
  const _RecommendationTags({required this.item});

  final PopupExitRecommendation item;

  @override
  Widget build(BuildContext context) {
    final tags = item.tagsName.isNotEmpty ? item.tagsName : item.categoryNames;
    if (tags.isEmpty) {
      return const SizedBox();
    }

    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tag in tags) ...[
              _RecommendationTag(label: tag),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationTag extends StatelessWidget {
  const _RecommendationTag({required this.label});

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
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 9,
          fontWeight: FontWeight.w400,
        ),
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
    return SizedBox(
      height: 37,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
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
