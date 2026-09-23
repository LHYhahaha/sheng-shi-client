import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../membership_layout.dart';
import '../../domain/membership_plan.dart';

class MembershipBenefitsPanel extends StatelessWidget {
  const MembershipBenefitsPanel({this.betweenBenefitsAndTips, super.key});

  /// 放置在权益列表和提示条款之间的可选内容。
  final Widget? betweenBenefitsAndTips;

  static const _gold = Color(0xFFE6CFA6);

  /// 内置的 4 个会员权益项。
  ///
  /// 文案来自 [AppLocalizations]，图片来自 assets/images/membership/。
  List<MembershipBenefit> _buildBenefits(AppLocalizations l10n) => [
    MembershipBenefit(
      iconPath: 'assets/images/membership/membership_series.png',
      title: l10n.benefitSeriesTitle,
      // highlight: l10n.benefitSeriesHighlight,
      description: l10n.benefitSeriesHighlight,
    ),
    // MembershipBenefit(
    //   iconPath: 'assets/images/membership/membership_download.png',
    //   title: l10n.benefitDownload,
    // ),
    MembershipBenefit(
      iconPath: 'assets/images/membership/membership_only.png',
      title: l10n.benefitMembersOnly,
    ),
    MembershipBenefit(
      iconPath: 'assets/images/membership/membership_hd.png',
      title: l10n.benefitHd,
    ),
    MembershipBenefit(
      iconPath: 'assets/images/membership/membership_ad.png',
      title: l10n.benefitNoAds,
    ),
  ];

  /// 内置的提示文案。
  ///
  /// 从 [AppLocalizations.membershipPaymentNote] 解析条款列表，
  /// 自动去除每行开头的编号（如 "1."、"2."）。
  MembershipTips _buildTips(AppLocalizations l10n) {
    final paymentNoteItems = l10n.membershipPaymentNote
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) {
          // 去掉开头的编号，如 "1.xxx" 或 "1. xxx"
          final match = RegExp(r'^\d+\.?\s*(.*)').firstMatch(item);
          return match != null ? match.group(1)! : item;
        })
        .toList();

    return MembershipTips(
      subscriptionNote: l10n.membershipAutoRenewCancel,
      items: paymentNoteItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final benefits = _buildBenefits(l10n);
    final tips = _buildTips(l10n);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: const Key('membership_benefits_panel'),
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight:
            MediaQuery.sizeOf(context).height -
            MembershipLayout.benefitsPanelTop +
            bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.fill,
                image: AssetImage(
                  "assets/images/membership/vip_bac_border.png",
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              MembershipLayout.horizontalPadding.w,
              MembershipLayout.benefitsTitlePaddingTop.w,
              MembershipLayout.horizontalPadding.w,
              20.w,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _BenefitTitleLine(reverse: true),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        l10n.membershipBenefits,
                        style: textTheme.bodyMedium?.copyWith(
                          color: _gold,
                          fontSize: 14.sp,
                          fontWeight: FontWeight(510),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const _BenefitTitleLine(),
                  ],
                ),
                SizedBox(height: 24.w),
                for (var index = 0; index < benefits.length; index++) ...[
                  _BenefitRow(benefit: benefits[index]),
                  if (index < benefits.length - 1)
                    SizedBox(height: MembershipLayout.benefitsRowGap.w),
                ],
              ],
            ),
          ),
          if (betweenBenefitsAndTips case final Widget content)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SizedBox(height: 20),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
                content,
              ],
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              MembershipLayout.horizontalPadding.w,
              16.w,
              MembershipLayout.horizontalPadding.w,
              28.w + bottomInset,
            ),
            child: _MembershipTips(tips: tips),
          ),
        ],
      ),
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
      width: MembershipLayout.benefitsTitleLineWidth.w,
      height: 1.w,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: MembershipLayout.benefitsIconSize.w,
          height: MembershipLayout.benefitsIconSize.w,
          child: Image.asset(
            benefit.iconPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
        SizedBox(width: 12.w),
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
                    fontSize: 14.sp,
                    height: 1.3,
                    fontWeight: FontWeight.normal,
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
              if (benefit.description != null) ...[
                SizedBox(height: 2.w),
                Text(
                  benefit.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: _gold.withValues(alpha: 0.4),
                    fontSize: 12.sp,
                    height: 1.3,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.normal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.membershipTips, style: style),
        const SizedBox(height: 6),
        // Text(tips.subscriptionNote, style: style),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.normal,
            ),
            children: [
              TextSpan(
                text: context.l10n.appCommonLegalPrivacyPolicy,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => context.push(RoutePaths.privacyPolicy),
              ),
              const TextSpan(text: '    ·    '),
              TextSpan(
                text: context.l10n.appCommonLegalTermsOfUse,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => context.push(RoutePaths.userAgreement),
              ),
            ],
          ),
        ),
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
