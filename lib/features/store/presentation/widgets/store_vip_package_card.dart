import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../core/utils/period_iso_parser.dart';
import '../../domain/store_package.dart';
import '../../application/store_controller.dart';
import '../../../pay/provider/iap_price_service_provider.dart';
import '../../../membership/application/promotion_countdown_service.dart';

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
    final title = context.l10n.rechargeMembershipTitle(
      periodIso: package.periodIso,
      fallbackId: package.id,
      fallbackTitle: package.title,
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
        final promoPrice = promo?['promoPrice'] as String?;
        final regularPrice = promo?['regularPrice'] as String?;
        final promoPeriod = promo?['promoPeriod'] as String?;
        final regularPeriod = promo?['regularPeriod'] as String?;
        if (promoPrice != null &&
            regularPrice != null &&
            promoPeriod != null &&
            regularPeriod != null) {
          promoDescription = IapPromoTextBuilder.build(
            promoPrice: promoPrice,
            promoPeriod: promoPeriod,
            promoCycles: promo?['promoCycles'] as int? ?? 1,
            regularPrice: regularPrice,
            regularPeriod: regularPeriod,
            hasFreeTrial: promo?['hasFreeTrial'] as bool? ?? false,
            languageCode: locale.languageCode,
          );
        }
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
                  child: _PromoCountdownBadge(package: package),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: _ink,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                        fontSize: 18,
                                      ),
                                ),
                                if (package.showsAutoRenewNotice) ...[
                                  const SizedBox(height: 9),
                                  Text(
                                    context.l10n.playerAutoRenewCancel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.normal,
                                          color: _ink.withValues(alpha: 0.6),
                                        ),
                                  ),
                                ],
                                if (promoDescription != null)
                                  Text(
                                    promoDescription,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10,
                                          color: _ink.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.normal,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                displayPrice,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: _priceInk,
                                      fontWeight: FontWeight.bold,
                                      height: 1.5,
                                      fontSize: 18,
                                    ),
                              ),
                              if (showPromo && displayOriginalPrice != null)
                                Text(
                                  displayOriginalPrice,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.normal,
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
                  ),
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

class _PromoCountdownBadge extends ConsumerStatefulWidget {
  const _PromoCountdownBadge({required this.package});

  final StorePackage package;

  @override
  ConsumerState<_PromoCountdownBadge> createState() =>
      _PromoCountdownBadgeState();
}

class _PromoCountdownBadgeState extends ConsumerState<_PromoCountdownBadge> {
  int _remainingSeconds = 0;
  PromotionCountdownService? _service;

  @override
  void initState() {
    super.initState();
    // 获取服务引用
    _service = ref.read(promotionCountdownServiceProvider);
    // 开始共享计时器（如果尚未开始）
    _service!.startIfNeeded().then((_) {
      if (!mounted) return;
      // 获取当前剩余时间
      setState(() {
        _remainingSeconds = _service!.remainingSeconds;
      });
    });
    // 添加监听器，每秒更新UI
    _service!.addListener(_updateCountdown);
  }

  void _updateCountdown() {
    if (!mounted) return;
    setState(() {
      _remainingSeconds = _service!.remainingSeconds;
    });
  }

  @override
  void dispose() {
    // 使用保存的服务引用，避免在dispose后使用ref
    _service?.removeListener(_updateCountdown);
    _service = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) {
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
        _formatCountdown(Duration(seconds: _remainingSeconds)),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
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
                  fontWeight: FontWeight.normal,
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
