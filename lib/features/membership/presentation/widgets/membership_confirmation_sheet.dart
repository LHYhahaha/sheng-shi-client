import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/utils/period_iso_parser.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_payment_method_sheet.dart';
import '../../../pay/domain/pay_channel.dart';
import '../../../pay/domain/payment_method_options.dart';
import '../../application/membership_controller.dart';
import '../../domain/membership_plan.dart';

class MembershipConfirmationSheet extends ConsumerWidget {
  const MembershipConfirmationSheet({
    required this.plan,
    required this.status,
    required this.onConfirm,
    required this.paymentMethods,
    required this.selectedPaymentMethodCode,
    required this.onPaymentMethodSelected,
    required this.onClose,
    super.key,
  });

  final MembershipPlan plan;
  final MembershipPurchaseStatus status;
  final VoidCallback onConfirm;
  final List<PaymentMethodOption> paymentMethods;
  final String? selectedPaymentMethodCode;
  final ValueChanged<String> onPaymentMethodSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      totalLabel: _selectedPriceLabel,
      statusLabel: statusLabel,
      isProcessing: isProcessing,
      isComplete: isComplete,
      onBuyNow: onConfirm,
      onClose: onClose,
      paymentMethods: _displayMethods(context),
      selectedPaymentMethodId: selectedPaymentMethodCode,
      onPaymentMethodSelected: (methodCode) {
        final position = paymentMethods.indexWhere(
          (method) => method.methodCode == methodCode,
        );
        if (position >= 0) {
          final method = paymentMethods[position];
          unawaited(
            ref
                .read(analyticsServiceProvider)
                .track(
                  AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                    'element_name': 'payment_method_item',
                    'payment_method_id': method.methodCode,
                    'payment_method_type':
                        PayChannel.analyticsPaymentMethodTypeFor(
                          method.payChannel,
                        ),
                    'position': position + 1,
                  }),
                ),
          );
        }
        onPaymentMethodSelected(methodCode);
      },
    );
  }

  List<AppPaymentMethod> _displayMethods(BuildContext context) => [
    for (final method in paymentMethods)
      AppPaymentMethod(
        id: method.methodCode,
        label: PayChannel.isGoogle(method.payChannel)
            ? context.l10n.paymentModalMethodGooglePay
            : PayChannel.isApple(method.payChannel)
            ? context.l10n.paymentModalMethodApplePay
            : method.methodName,
        iconAsset: PayChannel.isGoogle(method.payChannel)
            ? 'assets/images/membership/google_pay_icon.png'
            : PayChannel.isApple(method.payChannel)
            ? 'assets/images/membership/apple_pay_icon.png'
            : 'assets/images/membership/other_pay_icon.png',
        priceLabel: method.promotionPriceText.isNotEmpty
            ? method.promotionPriceText
            : method.priceText,
      ),
  ];

  String get _selectedPriceLabel {
    final method = paymentMethods
        .where((method) => method.methodCode == selectedPaymentMethodCode)
        .firstOrNull;
    if (method == null) return plan.priceLabel;
    return method.promotionPriceText.isNotEmpty
        ? method.promotionPriceText
        : method.priceText;
  }
}
