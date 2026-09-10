import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/drama_card_exposure.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../application/vip_only_dramas_provider.dart';
import '../../domain/vip_only_drama.dart';

/// 可复用于会员积分、开通及会员中心的会员专享短剧横滑区块。
///
/// 接口数据少于六部时不占用任何布局空间。
class VipOnlyDramasSection extends ConsumerWidget {
  static const _cardImageAspectRatio = 0.68;
  static const _visibleCardCount = 3.2;
  static const _titleHeight = 34.0;

  const VipOnlyDramasSection({
    required this.onDramaTap,
    this.padding = EdgeInsets.zero,
    this.listPadding = EdgeInsets.zero,
    this.backgroundColor,
    this.border,
    super.key,
    this.topPadding,
    this.needDivider,
    this.exposurePageSession,
    this.exposureAnalytics,
  });

  final void Function(VipOnlyDrama drama, int position) onDramaTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry listPadding;
  final Color? backgroundColor;
  final BoxBorder? border;
  final double? topPadding;
  final bool? needDivider;
  final Object? exposurePageSession;
  final AnalyticsService? exposureAnalytics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(vipOnlyDramasProvider).asData?.value;
    if (collection == null || !collection.canDisplay) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(color: backgroundColor, border: border),
      child: Padding(
        padding: EdgeInsets.only(top: topPadding ?? 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            needDivider != true
                ? SizedBox()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(
                        color: Colors.white.withValues(alpha: 0.12),
                        height: 1,
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
            Text(
              context.l10n.memberCenterSectionVipDramas,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth / _visibleCardCount;
                final listHeight =
                    cardWidth / _cardImageAspectRatio + _titleHeight + 6;

                return SizedBox(
                  height: listHeight,
                  child: ListView.separated(
                    key: const Key('vip_only_dramas_list'),
                    padding: listPadding,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: VipOnlyDramaCollection.minimumDisplayCount,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final drama = collection.dramas[index];
                      final card = _VipOnlyDramaCard(
                        width: cardWidth,
                        drama: drama,
                        onTap: () => onDramaTap(drama, index + 1),
                      );
                      final pageSession = exposurePageSession;
                      final analytics = exposureAnalytics;
                      if (pageSession == null || analytics == null) {
                        return card;
                      }
                      return DramaCardExposure(
                        pageSession: pageSession,
                        analytics: analytics,
                        dramaId: drama.id,
                        position: index + 1,
                        child: card,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VipOnlyDramaCard extends StatelessWidget {
  const _VipOnlyDramaCard({
    required this.width,
    required this.drama,
    required this.onTap,
  });

  final double width;
  final VipOnlyDrama drama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 109/147,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AppCachedNetworkImage(
                  imageUrl: drama.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFFFFFFF).withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
