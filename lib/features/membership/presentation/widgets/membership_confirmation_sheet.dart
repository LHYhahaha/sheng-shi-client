import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bottom_sheet_frame.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../application/membership_controller.dart';
import '../../domain/membership_plan.dart';

class MembershipConfirmationSheet extends StatelessWidget {
  const MembershipConfirmationSheet({
    required this.plan,
    required this.status,
    required this.onConfirm,
    required this.onCancel,
    required this.onClose,
    super.key,
  });

  final MembershipPlan plan;
  final MembershipPurchaseStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final isProcessing = status == MembershipPurchaseStatus.processing;
    final isComplete =
        status == MembershipPurchaseStatus.success ||
        status == MembershipPurchaseStatus.cancelled;
    final statusLabel = switch (status) {
      MembershipPurchaseStatus.idle => l10n.membershipMockPaymentNote,
      MembershipPurchaseStatus.processing => l10n.storePurchaseProcessing,
      MembershipPurchaseStatus.success => l10n.storePurchaseSuccess,
      MembershipPurchaseStatus.cancelled => l10n.storePurchaseCancelled,
    };

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
        Row(
          children: [
            if (isProcessing) ...[
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: status == MembershipPurchaseStatus.success
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: isComplete ? l10n.storeClose : l10n.storeConfirm,
          onPressed: isProcessing
              ? null
              : isComplete
              ? onClose
              : onConfirm,
        ),
        if (!isComplete)
          TextButton(
            onPressed: isProcessing ? null : onCancel,
            child: Text(l10n.storeCancel),
          ),
      ],
    );
  }
}
