import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/store_package.dart';

class StoreTipsSection extends StatelessWidget {
  const StoreTipsSection({required this.tips, super.key});

  final StoreTips tips;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
        Text(
          tips.linksLabel,
          style: textTheme.labelMedium?.copyWith(
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
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
