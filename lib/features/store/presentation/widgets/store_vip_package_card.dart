import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/utils/period_iso_parser.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../domain/store_package.dart';
import '../../application/store_controller.dart';
import '../../../pay/provider/iap_price_service_provider.dart';

class StoreVipPackageCard extends ConsumerWidget {
  const StoreVipPackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final StorePackage package;
  final bool selected;
  final VoidCallback onTap;

  static const _ink = Color(0xFF401908);
  static const _priceInk = Color(0xFF411803);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeState = ref.watch(storeControllerProvider);
    final iapProductDetails = storeState.iapProductDetails;
    final displayPrice = package.priceLabel;
    final displayOriginalPrice = package.originalPriceLabel;
    final showPromo = package.promotionExpireSeconds > 0;
    final title = PeriodIsoParser.localizedMembershipTitle(
      package.title,
      fallbackId: package.id,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    String? promoDescription;

    if (package.platformProductId != null &&
        iapProductDetails.containsKey(package.platformProductId)) {
      final productDetails = iapProductDetails[package.platformProductId];
      final promo = productDetails == null
          ? null
          : ref.read(iapPriceServiceProvider).extractPromoInfo(productDetails);
      if (promo?['hasPromo'] == true) {
        final locale = Localizations.localeOf(context);
        promoDescription = PeriodIsoParser.buildPromoDescription(
          promoPrice: promo?['promoPrice'] as String?,
          regularPrice: promo?['regularPrice'] as String?,
          promoPeriodIso: promo?['promoPeriod'] as String?,
          regularPeriodIso: promo?['regularPeriod'] as String?,
          languageCode: locale.languageCode,
        );
      }
    }

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 159,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF0D9), Color(0xFFF3CA92)],
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Image.asset(
                  "assets/images/profile/vip_v.png",
                  height: 98,
                  fit: BoxFit.contain,
                ),
              ),
              if (package.badgeLabel != null && !showPromo)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 19,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE3273),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(AppRadii.sm),
                      ),
                    ),
                    child: Text(
                      package.badgeLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (showPromo)
                Positioned(
                  right: -2,
                  top: -1,
                  child: _PromoCountdownBadge(
                    endTime: package.promotionExpiresAt,
                    fallbackSeconds: package.promotionExpireSeconds,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 17, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: _ink,
                                      fontWeight: FontWeight.w800,
                                      height: 1.5,
                                    ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                context.l10n.playerAutoRenewCancel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      color: _ink.withValues(alpha: 0.5),
                                    ),
                              ),
                              // 展示促销文案（替换footnote），没有促销则不展示
                              if (promoDescription != null)
                                Text(
                                  promoDescription,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: _ink.withValues(alpha: 0.5),
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              displayPrice, // 使用谷歌返回的价格或API返回的价格
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: _priceInk,
                                    fontWeight: FontWeight.w800,
                                    height: 1.5,
                                  ),
                            ),
                            if (showPromo && displayOriginalPrice != null)
                              Text(
                                displayOriginalPrice,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: _priceInk.withValues(alpha: 0.6),
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: _priceInk.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    color: const Color(0x33FFF8E7),
                    child: _BenefitGrid(benefits: package.benefits),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoCountdownBadge extends StatefulWidget {
  const _PromoCountdownBadge({
    required this.endTime,
    required this.fallbackSeconds,
  });

  final DateTime? endTime;
  final int fallbackSeconds;

  @override
  State<_PromoCountdownBadge> createState() => _PromoCountdownBadgeState();
}

class _PromoCountdownBadgeState extends State<_PromoCountdownBadge> {
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _endTime =
        widget.endTime ??
        DateTime.now().add(Duration(seconds: widget.fallbackSeconds));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (value) => value),
      builder: (context, snapshot) {
        final remainingSeconds = _endTime.difference(DateTime.now()).inSeconds;
        if (remainingSeconds <= 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF9E53), Color(0xFFFE1340), Color(0xFFFE3273)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppRadii.sm),
              topRight: Radius.circular(AppRadii.sm),
            ),
          ),
          child: Text(
            _formatCountdown(Duration(seconds: remainingSeconds)),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid({required this.benefits});

  final List<StorePackageBenefit> benefits;
  static const _ink = Color(0xFF401908);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: benefits.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 23,
        crossAxisSpacing: 13,
      ),
      itemBuilder: (context, index) {
        final benefit = benefits[index];
        final label = _localizedLabel(context, benefit.icon);
        return Row(
          children: [
            SvgPicture.asset(
              _iconFor(benefit.icon),
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _ink,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _localizedLabel(BuildContext context, StoreBenefitIcon icon) {
    return switch (icon) {
      StoreBenefitIcon.drama => context.l10n.rechargeBenefitUnlockDramas,
      StoreBenefitIcon.download => context.l10n.rechargeBenefitDownload,
      StoreBenefitIcon.hd => context.l10n.rechargeBenefitHd,
      StoreBenefitIcon.points => context.l10n.rechargeBenefitDailyPoints,
    };
  }

  String _iconFor(StoreBenefitIcon icon) {
    return switch (icon) {
      StoreBenefitIcon.drama => "assets/images/profile/brown_series.svg",
      StoreBenefitIcon.download => "assets/images/profile/brown_download.svg",
      StoreBenefitIcon.hd => "assets/images/profile/brown_hd.svg",
      StoreBenefitIcon.points => "assets/images/profile/brown_points.svg",
    };
  }
}

class _VipStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (double x = size.width * 0.5; x < size.width + 90; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x - 54, size.height * 0.75), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
