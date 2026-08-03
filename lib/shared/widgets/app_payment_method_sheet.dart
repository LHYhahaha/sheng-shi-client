import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppPaymentMethodSheet extends StatelessWidget {
  const AppPaymentMethodSheet({
    required this.orderTitle,
    required this.totalLabel,
    required this.statusLabel,
    required this.isProcessing,
    required this.isComplete,
    required this.onBuyNow,
    required this.onClose,
    required this.paymentMethods,
    required this.selectedPaymentMethodId,
    required this.onPaymentMethodSelected,
    this.height,
    this.closeButtonKey = const ValueKey('app_payment_close'),
    this.buyButtonKey = const ValueKey('app_payment_buy_now'),
    super.key,
  });

  final String orderTitle;
  final String totalLabel;
  final String statusLabel;
  final bool isProcessing;
  final bool isComplete;
  final VoidCallback onBuyNow;
  final VoidCallback onClose;
  final List<AppPaymentMethod> paymentMethods;
  final String? selectedPaymentMethodId;
  final ValueChanged<String> onPaymentMethodSelected;
  final double? height;
  final Key closeButtonKey;
  final Key buyButtonKey;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height - viewPadding.top - 24;
    final bottomSpacing = viewPadding.bottom + AppSpacing.xl;

    return Material(
      color: const Color(0xFF1D1D20),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height ?? maxSheetHeight),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerRight,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.membershipPayment,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 18,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isProcessing ? null : onClose,
                      child: SvgPicture.asset(
                        "assets/images/player/close.svg",
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              for (final method in paymentMethods)
                _PaymentMethodRow(
                  method: method,
                  selected: method.id == selectedPaymentMethodId,
                  enabled: !isProcessing,
                  onTap: () => onPaymentMethodSelected(method.id),
                ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _PaymentDetailRow(
                      label: '${context.l10n.paymentModalOrderDetails}:',
                      value: orderTitle,
                      valueKey: const ValueKey('app_payment_order_title'),
                    ),
                    const SizedBox(height: 22),
                    _PaymentDetailRow(
                      label: '${context.l10n.paymentModalAmountTotal}:',
                      value: totalLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: buyButtonKey,
                    onPressed: isProcessing
                        ? null
                        : isComplete
                        ? onClose
                        : onBuyNow,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.58,
                      ),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _PaymentButtonContent(
                      isProcessing: isProcessing,
                      label: isProcessing || isComplete
                          ? statusLabel
                          : context.l10n.storeBuyNow,
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottomSpacing),
            ],
          ),
        ),
      ),
    );
  }
}

class AppPaymentMethod {
  const AppPaymentMethod({
    required this.id,
    required this.label,
    required this.iconAsset,
    this.priceLabel,
  });

  final String id;
  final String label;
  final String iconAsset;
  final String? priceLabel;
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AppPaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            child: Row(
              children: [
                _PaymentRadio(selected: selected),
                const SizedBox(width: 12),
                Image.asset(method.iconAsset, width: 22, height: 22),
                const SizedBox(width: 8),
                Text(
                  method.label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    height: 1.25,
                  ),
                ),
                if (method.priceLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    method.priceLabel!,
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
      ],
    );
  }
}

class _PaymentRadio extends StatelessWidget {
  const _PaymentRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.4),
    ),
    child: selected
        ? const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          )
        : null,
  );
}

class _PaymentButtonContent extends StatelessWidget {
  const _PaymentButtonContent({
    required this.isProcessing,
    required this.label,
  });

  final bool isProcessing;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!isProcessing) {
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 17,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentDetailRow extends StatelessWidget {
  const _PaymentDetailRow({
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
