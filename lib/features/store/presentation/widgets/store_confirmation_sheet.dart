import 'package:flutter/material.dart';

import '../../../../core/utils/period_iso_parser.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_payment_method_sheet.dart';
import '../../application/store_controller.dart';
import '../../domain/store_package.dart';

class StoreConfirmationSheet extends StatelessWidget {
  const StoreConfirmationSheet({
    required this.package,
    required this.status,
    required this.onConfirm,
    required this.onClose,
    super.key,
  });

  final StorePackage package;
  final StorePurchaseStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final title = package.isCoinPackage
        ? package.title
        : PeriodIsoParser.localizedMembershipTitle(
            package.title,
            fallbackId: package.id,
            languageCode: languageCode,
          );

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

    return AppPaymentMethodSheet(
      orderTitle: title,
      totalLabel: package.priceLabel,
      statusLabel: statusLabel,
      isProcessing: isProcessing,
      isComplete: isComplete,
      onBuyNow: onConfirm,
      onClose: onClose,
    );
  }
}
