import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bottom_sheet_frame.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../application/store_controller.dart';
import '../../domain/store_package.dart';

/// 商店购买确认弹窗。
///
/// 弹窗只展示 StoreController 的本地流程态，并在 processing 期间禁用按钮。真实支付
/// 接入后，这里仍不应直接发放金币或会员权益，只负责把用户确认交给 controller。
class StoreConfirmationSheet extends StatelessWidget {
  const StoreConfirmationSheet({
    required this.package,
    required this.status,
    required this.onConfirm,
    required this.onCancel,
    required this.onClose,
    super.key,
  });

  final StorePackage package;
  final StorePurchaseStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final isProcessing =
        status == StorePurchaseStatus.creatingOrder ||
        status == StorePurchaseStatus.waitingPayment ||
        status == StorePurchaseStatus.verifying ||
        status == StorePurchaseStatus.pending;
    final isComplete =
        status == StorePurchaseStatus.success ||
        status == StorePurchaseStatus.failed ||
        status == StorePurchaseStatus.cancelled;
    final statusLabel = switch (status) {
      StorePurchaseStatus.idle => l10n.storePaymentNote,
      StorePurchaseStatus.creatingOrder => l10n.storePurchaseProcessing,
      StorePurchaseStatus.waitingPayment => l10n.storePurchaseProcessing,
      StorePurchaseStatus.verifying => l10n.storePurchaseProcessing,
      StorePurchaseStatus.pending => l10n.storePurchaseProcessing,
      StorePurchaseStatus.success => l10n.storePurchaseSuccess,
      StorePurchaseStatus.failed => l10n.storePurchaseFailed,
      StorePurchaseStatus.cancelled => l10n.storePurchaseCancelled,
    };

    return AppBottomSheetFrame(
      title: l10n.storeConfirmPurchase,
      children: [
        Row(
          children: [
            if (package.isCoinPackage)
              Image.asset(
                'assets/images/profile/coin.png',
                width: 28,
                height: 28,
              )
            else
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.gold,
                size: 30,
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (package.bonusLabel != null)
                    Text(
                      package.bonusLabel!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              package.priceLabel,
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
                  color: status == StorePurchaseStatus.success
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
