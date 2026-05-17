import 'package:flutter/material.dart';

import '../membership_layout.dart';
import '../../domain/membership_plan.dart';

class MembershipPlanCard extends StatelessWidget {
  const MembershipPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onTap;

  static const _gold = Color(0xFFD6BE94);
  static const _goldText = Color(0xFFFADEB7);

  static Key planKey(String planId) => Key('membership_plan_$planId');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: planKey(plan.id),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 28, 8, 25),
                child: Column(
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (plan.originalPriceLabel != null)
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
                    _PlanPriceText(
                      priceLabel: plan.priceLabel,
                      color: selected ? _goldText : Colors.white,
                    ),
                  ],
                ),
              ),
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
                      plan.dailyPriceLabel,
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
              if (plan.badgeLabel != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 65,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE3273),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      plan.badgeLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
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
