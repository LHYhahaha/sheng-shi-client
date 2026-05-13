import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../domain/membership_plan.dart';

class MembershipBenefitsPanel extends StatelessWidget {
  const MembershipBenefitsPanel({
    required this.benefits,
    required this.tips,
    super.key,
  });

  final List<MembershipBenefit> benefits;
  final MembershipTips? tips;

  static const _gold = Color(0xFFE6CFA6);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/membership/membership_benefits_panel_bg.png',
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) {
              return const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF131314),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _BenefitTitleLine(reverse: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      context.l10n.membershipBenefits,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _gold,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const _BenefitTitleLine(),
                ],
              ),
              const SizedBox(height: 28),
              for (final benefit in benefits) ...[
                _BenefitRow(benefit: benefit),
                const SizedBox(height: 20),
              ],
              if (tips != null) ...[
                const SizedBox(height: 4),
                _MembershipTips(tips: tips!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitTitleLine extends StatelessWidget {
  const _BenefitTitleLine({this.reverse = false});

  final bool reverse;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6CFA6);
    final colors = reverse
        ? [Colors.transparent, gold.withValues(alpha: 0.22)]
        : [gold.withValues(alpha: 0.22), Colors.transparent];

    return SizedBox(
      width: 52,
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});

  final MembershipBenefit benefit;

  static const _gold = Color(0xFFE6CFA6);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4B3C31), Color(0x004B3C31)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x3DFFEAC4)),
          ),
          child: Icon(_iconFor(benefit.icon), color: _gold, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: textTheme.bodyMedium?.copyWith(
                    color: _gold.withValues(alpha: 0.6),
                    fontSize: 14,
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(text: benefit.title),
                    if (benefit.highlight != null)
                      TextSpan(
                        text: benefit.highlight,
                        style: const TextStyle(color: _gold),
                      ),
                  ],
                ),
              ),
              if (benefit.description != null)
                Text(
                  benefit.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: _gold.withValues(alpha: 0.4),
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(MembershipBenefitIcon icon) {
    return switch (icon) {
      MembershipBenefitIcon.series => Icons.video_library_rounded,
      MembershipBenefitIcon.download => Icons.download_rounded,
      MembershipBenefitIcon.points => Icons.auto_awesome_rounded,
      MembershipBenefitIcon.membersOnly => Icons.workspace_premium_rounded,
      MembershipBenefitIcon.hd => Icons.hd_rounded,
      MembershipBenefitIcon.adFree => Icons.ad_units_rounded,
    };
  }
}

class _MembershipTips extends StatelessWidget {
  const _MembershipTips({required this.tips});

  final MembershipTips tips;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.4),
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.storeTips, style: style),
        const SizedBox(height: 6),
        Text(tips.subscriptionNote, style: style),
        const SizedBox(height: 6),
        for (var index = 0; index < tips.items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${index + 1}. ${tips.items[index]}', style: style),
          ),
      ],
    );
  }
}
