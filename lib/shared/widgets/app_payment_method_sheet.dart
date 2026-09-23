import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    final bottomSpacing = viewPadding.bottom + AppSpacing.xl.w;

    return Material(
      color: const Color(0xFF1D1D20),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.w)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: height == null ? maxSheetHeight : height!.w,
        ),
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
                    padding: EdgeInsets.symmetric(vertical: 26.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.membershipPayment,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16.w,
                    top: 18.w,
                    child: GestureDetector(
                      key: closeButtonKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: isProcessing ? null : onClose,
                      child: SvgPicture.asset(
                        "assets/images/player/close.svg",
                        width: 40.w,
                        height: 40.w,
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
              SizedBox(height: 20.w),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    _PaymentDetailRow(
                      label: '${context.l10n.paymentModalOrderDetails}:',
                      value: orderTitle,
                      valueKey: const ValueKey('app_payment_order_title'),
                    ),
                    SizedBox(height: 22.w),
                    _PaymentDetailRow(
                      label: '${context.l10n.paymentModalAmountTotal}:',
                      value: totalLabel,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40.w),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.w),
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
                      padding: EdgeInsets.symmetric(vertical: 13.w),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.58,
                      ),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                    ),
                    child: _PaymentButtonContent(
                      label: isComplete
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 17.w),
            child: Row(
              children: [
                _PaymentRadio(selected: selected),
                SizedBox(width: 12.w),
                Image.asset(method.iconAsset, width: 22.w, height: 22.w),
                SizedBox(width: 8.w),
                Text(
                  method.label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.normal,
                    height: 1.25,
                  ),
                ),
                if (method.priceLabel != null) ...[
                  SizedBox(width: 8.w),
                  Text(
                    method.priceLabel!,
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.45),
                      fontSize: 12.sp,
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
    width: 18.w,
    height: 18.w,
    padding: EdgeInsets.all(2.w),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.4.w),
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
  const _PaymentButtonContent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
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
              fontSize: 14.sp,
              height: 1.25,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Flexible(
          child: Text(
            value,
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
