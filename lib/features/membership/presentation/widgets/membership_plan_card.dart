import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/period_iso_parser.dart';
import '../../../../l10n/app_localizations.dart';
import '../membership_layout.dart';
import '../../domain/membership_plan.dart';
import '../../application/promotion_countdown_service.dart';

class MembershipPlanCard extends ConsumerStatefulWidget {
  const MembershipPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
    super.key,
  });

  static Key planKey(String planId) => Key('membership_plan_$planId');

  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  ConsumerState<MembershipPlanCard> createState() => _MembershipPlanCardState();
}

class _MembershipPlanCardState extends ConsumerState<MembershipPlanCard> {
  int _countdownSeconds = 0;
  PromotionCountdownService? _service;

  @override
  void initState() {
    super.initState();
    _initCountdown();
  }

  @override
  void didUpdateWidget(covariant MembershipPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当套餐 ID 或促销状态变化时，重新初始化倒计时
    if (oldWidget.plan.id != widget.plan.id ||
        oldWidget.plan.hasPromo != widget.plan.hasPromo) {
      _initCountdown();
    }
  }

  void _initCountdown() {
    // 只在有促销的套餐上启动 1 小时倒计时
    if (!widget.plan.hasPromo) {
      setState(() => _countdownSeconds = 0);
      return;
    }
    // 获取服务引用
    _service = ref.read(promotionCountdownServiceProvider);
    // 开始共享计时器（如果尚未开始）
    _service!.startIfNeeded().then((_) {
      if (!mounted) return;
      // 获取当前剩余时间
      setState(() {
        _countdownSeconds = _service!.remainingSeconds;
      });
    });
    // 添加监听器，每秒更新UI
    _service!.addListener(_updateCountdown);
  }

  void _updateCountdown() {
    if (!mounted) return;
    setState(() {
      _countdownSeconds = _service!.remainingSeconds;
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
    final textTheme = Theme.of(context).textTheme;
    final plan = widget.plan;
    final selected = widget.selected;
    final promotionText = _promotionText(context, plan);
    final title = context.l10n.membershipPlanTitle(
      periodIso: plan.period ?? plan.regularPeriodIso,
      fallbackId: plan.id,
      fallbackTitle: plan.title,
    );

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1C),
            borderRadius: BorderRadius.circular(
              MembershipLayout.planCardRadius,
            ),
            border: Border.all(
              width: 1,
              color: selected ? _gold : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 21 / 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PlanPriceText(
                          priceLabel: plan.priceLabel,
                          color: Colors.white,
                        ),
                        if (_originalPrice(plan) case final originalPrice?) ...[
                          const SizedBox(width: 6),
                          Text(
                            originalPrice,
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              height: 1.3,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.white.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (promotionText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        promotionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (plan.hasPromo && _countdownSeconds > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _CountdownTag(seconds: _countdownSeconds),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _originalPrice(MembershipPlan plan) =>
      plan.hasPromo ? plan.regularPriceLabel : plan.originalPriceLabel;

  String? _promotionText(BuildContext context, MembershipPlan plan) {
    if (plan.hasPromo &&
        plan.promotionPriceLabel != null &&
        plan.regularPriceLabel != null &&
        plan.promoPeriodIso != null &&
        plan.regularPeriodIso != null) {
      final args = IapPromoTextBuilder.templateArguments(
        promoPrice: plan.promotionPriceLabel!,
        promoPeriod: plan.promoPeriodIso!,
        promoCycles: plan.promoCycles ?? 1,
        regularPrice: plan.regularPriceLabel!,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      return context.l10n.vipPlanIntroPrice(
        sale: args['sale']!,
        price: args['price']!,
        num: args['num']!,
        ordinal: args['ordinal']!,
        unit: args['unit']!,
      );
    }

    return null;
  }
}

// ── 价格文字组件 ────────────────────────

class _PlanPriceText extends StatelessWidget {
  const _PlanPriceText({required this.priceLabel, required this.color});

  final String priceLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        priceLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: textTheme.headlineSmall?.copyWith(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight(510),
          height: 1.3,
        ),
      ),
    );
  }
}

// ── 倒计时标签组件 ────────────────────────

class _CountdownTag extends StatelessWidget {
  const _CountdownTag({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        image: DecorationImage(
          fit: BoxFit.fill,
          image: AssetImage(
            "assets/images/membership/membership_time_down_bac.png",
          ),
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
      ),
      child: Center(
        child: Text(
          _formatDuration(seconds),
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

// ── 颜色常量 ────────────────────────

const _gold = Color(0xFFD6BE94);
