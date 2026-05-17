import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../../domain/player_recharge_unlock_offer.dart';

/// 充值大抽屉之上的独立 Payment Method 小抽屉（不替换充值内容）。
class PlayerPaymentSelection {
  const PlayerPaymentSelection.coin(this.coinPackage)
    : membershipPackage = null;

  const PlayerPaymentSelection.membership(this.membershipPackage)
    : coinPackage = null;

  final PlayerRechargeCoinPackage? coinPackage;
  final PlayerRechargeMembershipPackage? membershipPackage;

  String get title {
    final coin = coinPackage;
    if (coin != null) {
      return '${coin.baseCoins} Coins';
    }
    return membershipPackage!.title;
  }

  String get priceLabel {
    final coin = coinPackage;
    if (coin != null) {
      return coin.googlePriceLabel;
    }
    return membershipPackage!.googlePriceLabel;
  }
}

class PlayerPaymentMethodSheet extends ConsumerStatefulWidget {
  const PlayerPaymentMethodSheet({
    required this.sessionKey,
    required this.selection,
    required this.onDismiss,
    required this.onPurchaseSuccess,
    super.key,
  });

  final String sessionKey;
  final PlayerPaymentSelection selection;
  final VoidCallback onDismiss;
  final VoidCallback onPurchaseSuccess;

  @override
  ConsumerState<PlayerPaymentMethodSheet> createState() =>
      _PlayerPaymentMethodSheetState();
}

class _PlayerPaymentMethodSheetState
    extends ConsumerState<PlayerPaymentMethodSheet> {
  var _didCompletePurchase = false;

  @override
  Widget build(BuildContext context) {
    final provider = playerRechargeUnlockControllerProvider(widget.sessionKey);
    ref.listen(provider.select((state) => state.status), (previous, next) {
      if (next != PlayerRechargeUnlockStatus.success ||
          _didCompletePurchase ||
          !mounted) {
        return;
      }
      _didCompletePurchase = true;
      widget.onPurchaseSuccess();
    });

    final state = ref.watch(provider);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = math.min(210.0, screenHeight - viewPadding.bottom - 72);

    return Padding(
      padding: EdgeInsets.only(bottom: viewPadding.bottom),
      child: Material(
        color: const Color(0xFF1D1D20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          width: double.infinity,
          child: _PaymentMethodContent(
            selection: widget.selection,
            isProcessing: state.isProcessing,
            onClose: widget.onDismiss,
            onBuyNow: () {
              final coin = widget.selection.coinPackage;
              if (coin != null) {
                unawaited(
                  ref.read(provider.notifier).selectCoinPackage(coin.id),
                );
                return;
              }
              final membership = widget.selection.membershipPackage;
              if (membership != null) {
                unawaited(
                  ref
                      .read(provider.notifier)
                      .selectMembershipPackage(membership.id),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodContent extends StatelessWidget {
  const _PaymentMethodContent({
    required this.selection,
    required this.isProcessing,
    required this.onClose,
    required this.onBuyNow,
  });

  final PlayerPaymentSelection selection;
  final bool isProcessing;
  final VoidCallback onClose;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey('player_recharge_payment_sheet'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
          child: Column(
            children: [
              SizedBox(
                height: 31,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Center(
                      child: Text(
                        'Payment method',
                        key: ValueKey('player_recharge_payment_method'),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 18 / 14,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: isProcessing ? null : onClose,
                        child: Container(
                          key: const ValueKey('player_recharge_payment_close'),
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 18, color: Colors.white.withValues(alpha: 0.08)),
              Row(
                children: [
                  const _PaymentRadio(),
                  const SizedBox(width: 8),
                  const _GooglePayMark(),
                  const SizedBox(width: 6),
                  Text(
                    'Google Pay',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              _PaymentDetailRow(
                label: 'Order details:',
                value: selection.title,
                valueKey: const ValueKey('player_recharge_payment_order_title'),
              ),
              const SizedBox(height: 12),
              _PaymentDetailRow(label: 'Total:', value: selection.priceLabel),
              const Spacer(),
              SizedBox(
                width: 196,
                height: 39,
                child: FilledButton(
                  key: const ValueKey('player_recharge_payment_buy_now'),
                  onPressed: isProcessing ? null : onBuyNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.48,
                    ),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Text(
                          'Buy now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentRadio extends StatelessWidget {
  const _PaymentRadio();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _GooglePayMark extends StatelessWidget {
  const _GooglePayMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFF34A853),
                  Color(0xFFFBBC05),
                  Color(0xFFEA4335),
                  Color(0xFF4285F4),
                ],
              ),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1D1D20),
            ),
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              height: 14 / 11,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 14 / 11,
            ),
          ),
        ),
      ],
    );
  }
}
