import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/store_package.dart';

class StoreTipsSection extends StatelessWidget {
  const StoreTipsSection({super.key});

  StoreTips _buildTips(AppLocalizations l10n) {
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

    return StoreTips(
      linksLabel: "",
      subscriptionNote: "",
      items: paymentNoteItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tips = _buildTips(context.l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.storeTips,
          style: textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimary.withValues(alpha: 0.4),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 11, color: Color(0xFFFFFFFF)),
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
        if (tips.subscriptionNote != "")
          Text(
            tips.subscriptionNote,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.4),
              height: 1.5,
            ),
          ),
        const SizedBox(height: 6),
        for (var index = 0; index < tips.items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${index + 1}. ${tips.items[index]}',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.4),
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
