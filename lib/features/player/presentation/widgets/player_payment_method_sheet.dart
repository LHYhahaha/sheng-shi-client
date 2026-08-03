import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/period_iso_parser.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_payment_method_sheet.dart';
import '../../../pay/domain/pay_channel.dart';
import '../../../pay/domain/payment_method_options.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../../domain/player_recharge_unlock_offer.dart';

class PlayerPaymentSelection {
  const PlayerPaymentSelection.coin(this.coinPackage)
    : membershipPackage = null;

  const PlayerPaymentSelection.membership(this.membershipPackage)
    : coinPackage = null;

  final PlayerRechargeCoinPackage? coinPackage;
  final PlayerRechargeMembershipPackage? membershipPackage;

  String titleFor(BuildContext context) {
    final coin = coinPackage;
    if (coin != null) {
      final coinLabel = '${coin.baseCoins} ${context.l10n.unitCoin}';
      if (coin.bonusCoins <= 0) {
        return coinLabel;
      }
      return '${coin.baseCoins} +${coin.bonusCoins} ${context.l10n.unitCoin}';
    }
    final package = membershipPackage!;
    return PeriodIsoParser.localizedMembershipTitle(
      package.title,
      fallbackId: package.id,
      languageCode: Localizations.localeOf(context).languageCode,
    );
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
  var _didDismissTerminalStatus = false;
  var _didDismissForGooglePayment = false;

  @override
  Widget build(BuildContext context) {
    final provider = playerRechargeUnlockControllerProvider(widget.sessionKey);
    ref.listen(provider.select((state) => state.paymentStage), (
      previous,
      next,
    ) {
      if (!mounted || _didDismissForGooglePayment) {
        return;
      }
      if (next == PlayerRechargePaymentStage.creatingOrder ||
          next == PlayerRechargePaymentStage.waitingPayment ||
          next == PlayerRechargePaymentStage.verifying) {
        _didDismissForGooglePayment = true;
        widget.onDismiss();
      }
    });
    ref.listen(provider.select((state) => state.status), (previous, next) {
      if (!mounted) {
        return;
      }
      if (next == PlayerRechargeUnlockStatus.success &&
          !_didDismissForGooglePayment &&
          !_didCompletePurchase) {
        _didCompletePurchase = true;
        widget.onPurchaseSuccess();
        return;
      }
      final shouldDismiss =
          next == PlayerRechargeUnlockStatus.failed ||
          next == PlayerRechargeUnlockStatus.cancelled;
      if (shouldDismiss && !_didDismissTerminalStatus) {
        _didDismissTerminalStatus = true;
        widget.onDismiss();
      }
    });

    final state = ref.watch(provider);
    final isProcessing = state.isProcessing;
    final isComplete =
        state.status == PlayerRechargeUnlockStatus.success ||
        state.status == PlayerRechargeUnlockStatus.failed;
    final statusLabel = switch (state.status) {
      PlayerRechargeUnlockStatus.processing =>
        context.l10n.storePurchaseProcessing,
      PlayerRechargeUnlockStatus.success => context.l10n.storePurchaseSuccess,
      PlayerRechargeUnlockStatus.failed => context.l10n.storePurchaseFailed,
      PlayerRechargeUnlockStatus.cancelled =>
        context.l10n.storePurchaseCancelled,
      _ => context.l10n.storePaymentNote,
    };

    return KeyedSubtree(
      key: const ValueKey('player_recharge_payment_sheet'),
      child: AppPaymentMethodSheet(
        orderTitle: widget.selection.titleFor(context),
        totalLabel: _selectedPriceLabel(state),
        statusLabel: statusLabel,
        isProcessing: isProcessing,
        isComplete: isComplete,
        closeButtonKey: const ValueKey('player_recharge_payment_close'),
        buyButtonKey: const ValueKey('player_recharge_payment_buy_now'),
        onClose: widget.onDismiss,
        onBuyNow: () {
          final coin = widget.selection.coinPackage;
          if (coin != null) {
            unawaited(
              ref
                  .read(provider.notifier)
                  .purchasePackageWithSelectedPayment(
                    packageId: coin.id,
                    isCoinPackage: true,
                  ),
            );
            return;
          }
          final membership = widget.selection.membershipPackage;
          if (membership != null) {
            unawaited(
              ref
                  .read(provider.notifier)
                  .purchasePackageWithSelectedPayment(
                    packageId: membership.id,
                    isCoinPackage: false,
                  ),
            );
          }
        },
        paymentMethods: _displayMethods(context, state.paymentMethods),
        selectedPaymentMethodId: state.selectedPaymentMethodCode,
        onPaymentMethodSelected: ref
            .read(provider.notifier)
            .selectPaymentMethod,
      ),
    );
  }

  List<AppPaymentMethod> _displayMethods(
    BuildContext context,
    List<PaymentMethodOption> methods,
  ) => [
    for (final method in methods)
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

  String _selectedPriceLabel(PlayerRechargeUnlockState state) {
    final method = state.paymentMethods
        .where((method) => method.methodCode == state.selectedPaymentMethodCode)
        .firstOrNull;
    if (method == null) return widget.selection.priceLabel;
    return method.promotionPriceText.isNotEmpty
        ? method.promotionPriceText
        : method.priceText;
  }
}
