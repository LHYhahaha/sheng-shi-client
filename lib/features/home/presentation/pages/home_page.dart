import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _tabs = ['Popular', 'New', 'Ranking', 'Original', 'Asian'];

  final _scrollController = ScrollController();
  final List<_HomeDramaCardData> _items = [];

  int _selectedTab = 0;
  int _page = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _items.addAll(_buildPage(0));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 500) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) {
      return;
    }

    final nextPage = _page + 1;
    setState(() {
      _page = nextPage;
      _items.addAll(_buildPage(nextPage));
      _isLoadingMore = false;
      _hasMore = nextPage < 3;
    });
  }

  void _selectTab(int index) {
    if (_selectedTab == index) {
      return;
    }

    setState(() {
      _selectedTab = index;
      _page = 0;
      _hasMore = true;
      _isLoadingMore = false;
      _items
        ..clear()
        ..addAll(_buildPage(0));
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 29, 16, 0),
                child: _HomeTitleBar(
                  onMembershipTap: () => context.go(RoutePaths.membership),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeTabsHeaderDelegate(
                selectedTab: _selectedTab,
                tabs: _tabs,
                onTabChanged: _selectTab,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(13, 18, 13, 24),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 9,
                childCount: _items.length,
                itemBuilder: (context, index) {
                  return _HomeDramaCard(
                    data: _items[index],
                    onTap: () {
                      context.go(
                        RoutePaths.playerLocation(
                          dramaId: _items[index].id,
                          episodeId: 'episode-1',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _HomeFeedFooter(
                isLoading: _isLoadingMore,
                hasMore: _hasMore,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_HomeDramaCardData> _buildPage(int page) {
    final tab = _tabs[_selectedTab];
    final seed = page * 6;

    return [
      _HomeDramaCardData(
        id: '$tab-$seed-0',
        title: 'Found You,Hea',
        tags: const ['Rebirth'],
        imageAspectRatio: 171 / 226,
      ),
      _HomeDramaCardData(
        id: '$tab-$seed-1',
        title: 'Found You,Heart\nThiefFound You,Heart Th...',
        tags: const ['Rebirth', 'Rebirth'],
        imageAspectRatio: 171 / 242,
        isExclusive: true,
      ),
      _HomeDramaCardData(
        id: '$tab-$seed-2',
        title: 'Found You,Hea',
        tags: const ['Rebirth'],
        imageAspectRatio: 171 / 236,
      ),
      _HomeDramaCardData(
        id: '$tab-$seed-3',
        title: 'Found You,Heart\nThiefFound You,Heart Th...',
        tags: const ['Rebirth'],
        imageAspectRatio: 171 / 205,
      ),
      _HomeDramaCardData(
        id: '$tab-$seed-4',
        title: 'Found You,Hea',
        tags: const ['Rebirth'],
        imageAspectRatio: 171 / 260,
      ),
      _HomeDramaCardData(
        id: '$tab-$seed-5',
        title: 'Found You,Heart\nThiefFound You,Heart Th...',
        tags: const ['Rebirth'],
        imageAspectRatio: 171 / 232,
      ),
    ];
  }
}

class _HomeTitleBar extends StatelessWidget {
  const _HomeTitleBar({required this.onMembershipTap});

  final VoidCallback onMembershipTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'KiligBox',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        GestureDetector(
          onTap: onMembershipTap,
          child: const Padding(
            padding: EdgeInsets.only(right: 1),
            child: _VipCrown(),
          ),
        ),
      ],
    );
  }
}

class _VipCrown extends StatelessWidget {
  const _VipCrown();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 39,
      height: 31,
      child: CustomPaint(painter: _VipCrownPainter()),
    );
  }
}

class _VipCrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF5A2D00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final crown = Path()
      ..moveTo(size.width * 0.08, size.height * 0.35)
      ..lineTo(size.width * 0.28, size.height * 0.56)
      ..lineTo(size.width * 0.50, size.height * 0.18)
      ..lineTo(size.width * 0.72, size.height * 0.56)
      ..lineTo(size.width * 0.92, size.height * 0.35)
      ..lineTo(size.width * 0.82, size.height * 0.82)
      ..lineTo(size.width * 0.18, size.height * 0.82)
      ..close();

    canvas.drawPath(crown, fill);
    canvas.drawPath(crown, stroke);

    final dotPaint = Paint()..color = const Color(0xFFFFC35A);
    for (final center in [
      Offset(size.width * 0.08, size.height * 0.35),
      Offset(size.width * 0.50, size.height * 0.18),
      Offset(size.width * 0.92, size.height * 0.35),
    ]) {
      canvas.drawCircle(center, 3.1, dotPaint);
    }

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'VIP',
        style: TextStyle(
          color: Color(0xFF6F3700),
          fontSize: 7,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeTabsHeaderDelegate({
    required this.tabs,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.black,
          boxShadow: overlapsContent
              ? [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.72),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 13, 0, 0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tabs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 31),
            itemBuilder: (context, index) {
              return _HomeCategoryTab(
                label: tabs[index],
                selected: index == selectedTab,
                onTap: () => onTabChanged(index),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeTabsHeaderDelegate oldDelegate) {
    return oldDelegate.selectedTab != selectedTab || oldDelegate.tabs != tabs;
  }
}

class _HomeCategoryTab extends StatelessWidget {
  const _HomeCategoryTab({
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
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 16,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _HomeDramaCard extends StatelessWidget {
  const _HomeDramaCard({required this.data, required this.onTap});

  final _HomeDramaCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2B2235),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: data.imageAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Image(
                    image: AssetImage('assets/mock/drama_cover.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x66000000),
                        ],
                      ),
                    ),
                  ),
                  if (data.isExclusive)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: _ExclusiveBadge(),
                    ),
                  const Positioned(right: 9, bottom: 10, child: _ViewCount()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 18,
                    child: Row(
                      children: [
                        for (final tag in data.tags.indexed) ...[
                          Flexible(child: _HomeTag(label: tag.$2)),
                          if (tag.$1 != data.tags.length - 1)
                            const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExclusiveBadge extends StatelessWidget {
  const _ExclusiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.sm),
        ),
      ),
      child: Text(
        'Exclusive',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }
}

class _ViewCount extends StatelessWidget {
  const _ViewCount();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow, color: AppColors.textPrimary, size: 14),
        const SizedBox(width: 2),
        Text(
          '84.1 M',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textPrimary,
            fontSize: 11,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _HomeTag extends StatelessWidget {
  const _HomeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 58, maxWidth: 68),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF5E5864),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFFC5BEC9),
          fontSize: 10,
          height: 1,
        ),
      ),
    );
  }
}

class _HomeFeedFooter extends StatelessWidget {
  const _HomeFeedFooter({required this.isLoading, required this.hasMore});

  final bool isLoading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Center(
          child: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  hasMore ? '' : 'There is no content for now~',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
        ),
      ),
    );
  }
}

class _HomeDramaCardData {
  const _HomeDramaCardData({
    required this.id,
    required this.title,
    required this.tags,
    required this.imageAspectRatio,
    this.isExclusive = false,
  });

  final String id;
  final String title;
  final List<String> tags;
  final double imageAspectRatio;
  final bool isExclusive;
}
