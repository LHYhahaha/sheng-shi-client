import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';

import '../../../../app/app_modal_context.dart';
import '../../../../core/modal/app_modal_presenter.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_root_sheet.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../domain/player_feed.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_payment_method_modal_layer.dart';
import '../widgets/player_recharge_unlock_sheet.dart';
import 'player_modal_channels.dart';
import 'player_modal_payloads.dart';

/// Player 瑙ｉ攣/鍏呭€煎脊绐?presenter锛氶€氳繃 root bottom sheet 灞曠ず锛岄伩鍏?tab 閬尅銆?
class PlayerAppModalPresenter implements AppModalPresenter {
  const PlayerAppModalPresenter();

  @override
  bool handles(AppModalRequest request) {
    return request is FeatureAppModalRequest &&
        (request.channel == PlayerModalChannels.coinUnlock ||
            request.channel == PlayerModalChannels.rechargeUnlock ||
            request.channel == PlayerModalChannels.paymentMethod);
  }

  @override
  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  }) {
    final featureRequest = request as FeatureAppModalRequest;
    return switch (featureRequest.channel) {
      PlayerModalChannels.coinUnlock => _presentCoinUnlock(
        context,
        featureRequest,
      ),
      PlayerModalChannels.rechargeUnlock => _presentRechargeUnlock(
        context,
        featureRequest,
      ),
      PlayerModalChannels.paymentMethod => _presentPaymentMethod(
        context,
        featureRequest,
      ),
      _ => Future.value(ConfirmResult.dismissed),
    };
  }

  Future<AppModalResult> _presentCoinUnlock(
    BuildContext context,
    FeatureAppModalRequest request,
  ) async {
    final payload = request.payload as PlayerCoinUnlockModalPayload?;

    if (payload == null) {
      return const CoinUnlockModalResult.dismissed();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final container = ProviderScope.containerOf(modalContext, listen: false);
    final balance =
        container.read(entitlementControllerProvider).coinBalance +
        container.read(entitlementControllerProvider).bonusBalance;
    final sessionKey = payload.sessionKey;
    final itemId = payload.itemId;
    final price = payload.price;

    // 浠?feed controller 鑾峰彇瀹屾暣鐨?item 淇℃伅
    final feedState = container.read(playerFeedControllerProvider(sessionKey));
    PlayerFeedItem? item;
    for (final candidate in feedState.items) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }

    if (item == null) {
      debugPrint('[_presentCoinUnlock] 鏈壘鍒?item: $itemId');
      return const CoinUnlockModalResult.cancelled();
    }

    final unlocked = await showAppModalRootBottomSheet<bool>(
      context: modalContext,
      builder: (sheetContext) {
        return PlayerCoinUnlockSheet(
          price: price,
          balance: balance,
          onConfirm: () async {
            // 璋冪敤瑙ｉ攣 API
            final navigator = Navigator.of(sheetContext);
            try {
              debugPrint(
                '[_presentCoinUnlock] 寮€濮嬭皟鐢ㄨВ閿?API锛宨temId=$itemId, price=$price',
              );
              final dramaId = int.tryParse(item!.content.id) ?? 0;
              final episodeNo = item.episode.number;
              final shortTitle = item.content.playTitle.isNotEmpty
                  ? item.content.playTitle
                  : item.content.title;
              final cover = item.content.coverUrl ?? '';
              final episodeId = int.tryParse(item.episode.id);

              if (episodeId == null) {
                debugPrint(
                  '[_presentCoinUnlock] episode id parse failed: ${item.episode.id}',
                );
                navigator.pop(false);
                return;
              }

              unawaited(
                container
                    .read(analyticsServiceProvider)
                    .track(
                      AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                        'element_name': 'episode_unlock_button',
                        'drama_id': item.content.id,
                        'episode_id': item.episode.id,
                        'unlock_button_action': 'confirm_unlock',
                      }),
                    ),
              );

              final controller = container.read(
                playerRechargeUnlockControllerProvider(sessionKey).notifier,
              );
              await controller.unlockWithCoin(
                autoUnlockNext: false,
                coin: price,
                dramaId: dramaId,
                episodeNo: episodeNo,
                shortTitle: shortTitle,
                cover: cover,
                episodeId: episodeId,
                requestId: request.requestId,
              );

              final unlockState = container.read(
                playerRechargeUnlockControllerProvider(sessionKey),
              );
              if (unlockState.status == PlayerRechargeUnlockStatus.success) {
                debugPrint('[_presentCoinUnlock] unlock succeeded');
                navigator.pop(true);
              } else {
                debugPrint('[_presentCoinUnlock] 瑙ｉ攣澶辫触: success=false');
                navigator.pop(false);
              }
            } catch (e, st) {
              debugPrint('[_presentCoinUnlock] 瑙ｉ攣寮傚父: $e\n$st');
              navigator.pop(false);
            }
          },
        );
      },
    );

    if (unlocked == true) {
      return const CoinUnlockModalResult.completed();
    }
    if (request.dismissPolicy.barrierDismissible) {
      return const CoinUnlockModalResult.dismissed();
    }
    return const CoinUnlockModalResult.cancelled();
  }

  Future<AppModalResult> _presentRechargeUnlock(
    BuildContext context,
    FeatureAppModalRequest request,
  ) async {
    final payload = request.payload as PlayerRechargeUnlockModalPayload?;

    if (payload == null) {
      return const RechargeModalResult.cancelled();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final unlocked = await showAppModalRootBottomSheet<bool>(
      context: modalContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return PlayerRechargeUnlockSheet(
          sessionKey: payload.sessionKey,
          dramaId: payload.dramaId,
          episodeNo: payload.episodeNo,
          shortTitle: payload.shortTitle,
          cover: payload.cover,
          episodeId: payload.episodeId,
        );
      },
    );

    if (unlocked == true) {
      return const RechargeModalResult.completed();
    }
    if (request.dismissPolicy.barrierDismissible && unlocked == null) {
      return const RechargeModalResult.cancelled();
    }
    return const RechargeModalResult.cancelled();
  }

  Future<AppModalResult> _presentPaymentMethod(
    BuildContext context,
    FeatureAppModalRequest request,
  ) async {
    final payload = request.payload as PlayerPaymentMethodModalPayload?;

    if (payload == null) {
      return const PaymentModalResult.cancelled();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final container = ProviderScope.containerOf(modalContext, listen: false);
    final purchased = await showGeneralDialog<bool>(
      context: modalContext,
      barrierDismissible: request.dismissPolicy.barrierDismissible,
      barrierLabel: MaterialLocalizations.of(
        modalContext,
      ).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, _) {
        return MediaQuery(
          data: MediaQuery.of(modalContext),
          child: PlayerPaymentMethodModalLayer(
            sessionKey: payload.sessionKey,
            selection: payload.selection,
            onDismissed: (result) => Navigator.of(dialogContext).pop(result),
            onPurchaseSuccess: () => Navigator.of(dialogContext).pop(true),
          ),
        );
      },
    );

    final rechargeProvider = playerRechargeUnlockControllerProvider(
      payload.sessionKey,
    );
    final rechargeState = container.read(rechargeProvider);
    if (_shouldWaitForPlayerPaymentTerminalStatus(rechargeState)) {
      final finalStatus = await _waitForPlayerPaymentTerminalStatus(
        container,
        payload.sessionKey,
      );
      return switch (finalStatus) {
        PlayerRechargeUnlockStatus.success =>
          const PaymentModalResult.completed(),
        PlayerRechargeUnlockStatus.failed => const PaymentModalResult.failed(),
        PlayerRechargeUnlockStatus.cancelled =>
          const PaymentModalResult.cancelled(),
        _ => const PaymentModalResult.cancelled(),
      };
    }
    if (rechargeState.status == PlayerRechargeUnlockStatus.failed) {
      return const PaymentModalResult.failed();
    }
    if (rechargeState.status == PlayerRechargeUnlockStatus.cancelled) {
      return const PaymentModalResult.cancelled();
    }
    if (purchased == true) {
      return const PaymentModalResult.completed();
    }
    if (request.dismissPolicy.barrierDismissible && purchased == null) {
      return const PaymentModalResult.dismissed();
    }
    return const PaymentModalResult.cancelled();
  }

  Future<PlayerRechargeUnlockStatus?> _waitForPlayerPaymentTerminalStatus(
    ProviderContainer container,
    String sessionKey,
  ) async {
    final provider = playerRechargeUnlockControllerProvider(sessionKey);
    final currentStatus = container.read(
      provider.select((state) => state.status),
    );
    if (_isPlayerPaymentTerminal(currentStatus)) {
      return currentStatus;
    }

    final completer = Completer<PlayerRechargeUnlockStatus?>();
    late final ProviderSubscription<PlayerRechargeUnlockStatus> subscription;
    subscription = container.listen<PlayerRechargeUnlockStatus>(
      provider.select((state) => state.status),
      (previous, next) {
        if (_isPlayerPaymentTerminal(next) && !completer.isCompleted) {
          completer.complete(next);
        }
      },
    );
    try {
      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => PlayerRechargeUnlockStatus.failed,
      );
    } finally {
      subscription.close();
    }
  }

  bool _isPlayerPaymentTerminal(PlayerRechargeUnlockStatus status) {
    return status == PlayerRechargeUnlockStatus.success ||
        status == PlayerRechargeUnlockStatus.failed ||
        status == PlayerRechargeUnlockStatus.cancelled;
  }

  bool _shouldWaitForPlayerPaymentTerminalStatus(
    PlayerRechargeUnlockState state,
  ) {
    return state.status == PlayerRechargeUnlockStatus.processing &&
        (state.paymentStage == PlayerRechargePaymentStage.creatingOrder ||
            state.paymentStage == PlayerRechargePaymentStage.waitingPayment ||
            state.paymentStage == PlayerRechargePaymentStage.verifying);
  }
}
