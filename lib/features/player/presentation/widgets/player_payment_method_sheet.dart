import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/toast/app_toast_provider.dart';
import '../../../../core/utils/period_iso_parser.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_payment_method_sheet.dart';
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
      return '${coin.baseCoins} Coins';
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
      ref.read(appToastProvider).success(context.l10n.storePurchaseSuccess);
      widget.onPurchaseSuccess();
    });

    final state = ref.watch(provider);
    final isProcessing = state.isProcessing;
    final isComplete =
        state.status == PlayerRechargeUnlockStatus.success ||
        state.status == PlayerRechargeUnlockStatus.failed ||
        state.status == PlayerRechargeUnlockStatus.cancelled;
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
        totalLabel: widget.selection.priceLabel,
        statusLabel: statusLabel,
        isProcessing: isProcessing,
        isComplete: isComplete,
        closeButtonKey: const ValueKey('player_recharge_payment_close'),
        buyButtonKey: const ValueKey('player_recharge_payment_buy_now'),
        onClose: widget.onDismiss,
        onBuyNow: () {
          final coin = widget.selection.coinPackage;
          if (coin != null) {
            unawaited(ref.read(provider.notifier).selectCoinPackage(coin.id));
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
    );
  }
}
