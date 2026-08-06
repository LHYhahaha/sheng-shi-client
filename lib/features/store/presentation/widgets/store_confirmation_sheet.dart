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
import '../../application/store_controller.dart';
import '../../domain/store_package.dart';

class StoreConfirmationSheet extends ConsumerWidget {
  const StoreConfirmationSheet({
    required this.package,
    required this.status,
    required this.onConfirm,
    required this.paymentMethods,
    required this.selectedPaymentMethodCode,
    required this.onPaymentMethodSelected,
    required this.onClose,
    super.key,
  });

  final StorePackage package;
  final StorePurchaseStatus status;
  final VoidCallback onConfirm;
  final List<PaymentMethodOption> paymentMethods;
  final String? selectedPaymentMethodCode;
  final ValueChanged<String> onPaymentMethodSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final title = package.isCoinPackage
        ? _coinOrderTitle(context, package)
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

  String _coinOrderTitle(BuildContext context, StorePackage package) {
    final coinLabel = '${package.baseCoins} ${context.l10n.unitCoin}';
    if (package.bonusCoins <= 0) {
      return coinLabel;
    }
    return '${package.baseCoins} +${package.bonusCoins} ${context.l10n.unitCoin}';
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
    if (method == null) return package.priceLabel;
    return method.promotionPriceText.isNotEmpty
        ? method.promotionPriceText
        : method.priceText;
  }
}
