import 'package:flutter/material.dart';

import '../../../../core/utils/period_iso_parser.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_payment_method_sheet.dart';
import '../../application/membership_controller.dart';
import '../../domain/membership_plan.dart';

class MembershipConfirmationSheet extends StatelessWidget {
  const MembershipConfirmationSheet({
    required this.plan,
    required this.status,
    required this.onConfirm,
    required this.onClose,
    super.key,
  });

  final MembershipPlan plan;
  final MembershipPurchaseStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final title = PeriodIsoParser.localizedMembershipTitle(
      plan.title,
      periodIso: plan.period ?? plan.regularPeriodIso,
      fallbackId: plan.id,
      languageCode: languageCode,
    );

    final isProcessing =
        status == MembershipPurchaseStatus.creatingOrder ||
        status == MembershipPurchaseStatus.waitingPayment ||
        status == MembershipPurchaseStatus.verifying ||
        status == MembershipPurchaseStatus.pending;
    final isComplete =
        status == MembershipPurchaseStatus.success ||
        status == MembershipPurchaseStatus.failed ||
        status == MembershipPurchaseStatus.cancelled;
    final statusLabel = switch (status) {
      MembershipPurchaseStatus.idle => l10n.storePaymentNote,
      MembershipPurchaseStatus.creatingOrder => l10n.storePurchaseProcessing,
      MembershipPurchaseStatus.waitingPayment => l10n.storePurchaseProcessing,
      MembershipPurchaseStatus.verifying => l10n.storePurchaseProcessing,
      MembershipPurchaseStatus.pending => l10n.storePurchaseProcessing,
      MembershipPurchaseStatus.success => l10n.storePurchaseSuccess,
      MembershipPurchaseStatus.failed => l10n.storePurchaseFailed,
      MembershipPurchaseStatus.cancelled => l10n.storePurchaseCancelled,
    };

    return AppPaymentMethodSheet(
      orderTitle: title,
      totalLabel: plan.priceLabel,
      statusLabel: statusLabel,
      isProcessing: isProcessing,
      isComplete: isComplete,
      onBuyNow: onConfirm,
      onClose: onClose,
    );
  }
}
