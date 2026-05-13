import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bottom_sheet_frame.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../domain/store_package.dart';

class StoreConfirmationSheet extends StatelessWidget {
  const StoreConfirmationSheet({
    required this.package,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final StorePackage package;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
        Text(
          l10n.storeMockPaymentNote,
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
