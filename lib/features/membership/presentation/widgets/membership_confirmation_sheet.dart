import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bottom_sheet_frame.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../domain/membership_plan.dart';

class MembershipConfirmationSheet extends StatelessWidget {
  const MembershipConfirmationSheet({
    required this.plan,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final MembershipPlan plan;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppBottomSheetFrame(
      title: l10n.membershipConfirmPurchase,
      children: [
        Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.gold,
              size: 30,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                plan.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              plan.priceLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.membershipMockPaymentNote,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(label: l10n.storeConfirm, onPressed: onConfirm),
        TextButton(onPressed: onCancel, child: Text(l10n.storeCancel)),
      ],
    );
  }
}
