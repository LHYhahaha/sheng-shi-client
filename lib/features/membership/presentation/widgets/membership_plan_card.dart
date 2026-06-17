import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/period_iso_parser.dart';
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
    final languageCode = Localizations.localeOf(context).languageCode;
    final title = PeriodIsoParser.localizedMembershipTitle(
      plan.title,
      periodIso: plan.period ?? plan.regularPeriodIso,
      fallbackId: plan.id,
      languageCode: languageCode,
    );
    final dailyPriceLabel = PeriodIsoParser.localizedDailyPriceLabel(
      plan.dailyPriceLabel,
      languageCode: languageCode,
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
          width: MembershipLayout.planCardWidth,
          height: MembershipLayout.planCardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1C),
            borderRadius: BorderRadius.circular(
              MembershipLayout.planCardRadius,
            ),
            border: Border.all(
              color: selected ? _gold : Colors.white.withValues(alpha: 0.24),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 28, 8, 25),
                child: Column(
                  children: [
                    Row(),
                    // 标题
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 原价（划掉）—— 有促销时显示续费原价
                    if (plan.hasPromo && plan.regularPriceLabel != null)
                      Text(
                        plan.regularPriceLabel!,
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white.withValues(alpha: 0.5),
                          height: 1.2,
                        ),
                      )
                    else if (plan.originalPriceLabel != null)
                      Text(
                        plan.originalPriceLabel!,
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white.withValues(alpha: 0.5),
                          height: 1.2,
                        ),
                      )
                    else
                      const SizedBox(height: 14),

                    const SizedBox(height: 4),

                    // 主价格（促销价 或 原价）
                    _PlanPriceText(
                      priceLabel: plan.priceLabel,
                      color: selected ? _goldText : Colors.white,
                    ),

                    const Spacer(),

                    // 底部留白，促销文案已移至卡片外部
                  ],
                ),
              ),

              // 底部日均价栏
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 25,
                child: ColoredBox(
                  color: selected
                      ? _goldText
                      : Colors.white.withValues(alpha: 0.08),
                  child: Center(
                    child: Text(
                      dailyPriceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: selected
                            ? const Color(0xFF5A280A)
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              // 右上角倒计时标签（有促销 + 倒计时未结束时展示）
              if (plan.hasPromo && _countdownSeconds > 0)
                Positioned(
                  top: -1,
                  right: -1,
                  child: _CountdownTag(seconds: _countdownSeconds),
                ),
            ],
          ),
        ),
      ),
    );
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
    final hasDollarPrefix = priceLabel.startsWith(r'$');
    final price = hasDollarPrefix ? priceLabel.substring(1) : priceLabel;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: RichText(
        maxLines: 1,
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            if (hasDollarPrefix)
              TextSpan(
                text: r'$',
                style: textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            TextSpan(
              text: price,
              style: textTheme.headlineSmall?.copyWith(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
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
const _goldText = Color(0xFFFADEB7);
