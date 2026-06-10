import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/modal/app_modal_controller.dart';
import '../../../core/modal/app_modal_policy.dart';
import '../../../core/modal/app_modal_provider.dart';
import '../../../core/modal/app_modal_request.dart';
import '../../../core/modal/app_modal_service.dart';
import '../../../core/modal/app_modal_source.dart';
import '../../../core/toast/app_toast_provider.dart';
import '../../../core/toast/app_toast_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../app/router/route_names.dart';
import '../domain/player_feed.dart';
import '../presentation/modal/player_modal_channels.dart';
import '../presentation/modal/player_modal_payloads.dart';
import '../presentation/modal/player_modal_results.dart';
import 'player_feed_engine.dart';
import 'player_feed_engine_access_flow.dart';
import 'player_overlay_orchestrator.dart';
import 'player_recharge_unlock_controller.dart';

/// Player 解锁/充值弹窗编排：统一走 [AppModalService]，避免 Page 直接 showModalBottomSheet。
class PlayerUnlockModalCoordinator {
  PlayerUnlockModalCoordinator({
    required String sessionKey,
    required AppModalService modalService,
    required AppModalController modalController,
    required PlayerFeedEngine engine,
    required PlayerOverlayOrchestrator overlayOrchestrator,
    required AppToastService appToast,
    required PlayerRechargeUnlockController rechargeController,
    required PlayerRechargeUnlockState Function() readRechargeState,
  }) : _sessionKey = sessionKey,
       _modalService = modalService,
       _modalController = modalController,
       _engine = engine,
       _overlay = overlayOrchestrator,
       _appToast = appToast,
       _rechargeController = rechargeController,
       _readRechargeState = readRechargeState;

  final String _sessionKey;
  final AppModalService _modalService;
  final AppModalController _modalController;
  final PlayerFeedEngine _engine;
  final PlayerOverlayOrchestrator _overlay;
  final AppToastService _appToast;
  final PlayerRechargeUnlockController _rechargeController;
  final PlayerRechargeUnlockState Function() _readRechargeState;

  Future<void> presentSheetIntent(
    BuildContext context,
    PlayerFeedItem item,
    PlayerOverlaySheetIntent intent, {
    bool launchedByAutoSheet = false,
  }) async {
    if (!context.mounted || !_engine.isCurrentFeedItem(item)) {
      return;
    }
    switch (intent) {
      case PlayerOverlaySheetIntent.none:
        return;
      case PlayerOverlaySheetIntent.coinUnlock:
        await showCoinUnlock(
          context,
          item,
          launchedByAutoSheet: launchedByAutoSheet,
        );
      case PlayerOverlaySheetIntent.rechargeUnlock:
        await showRechargeUnlock(
          context,
          item,
          launchedByAutoSheet: launchedByAutoSheet,
        );
      case PlayerOverlaySheetIntent.membership:
        // 纯会员剧：直接跳转到会员开通页面
        await context.pushNamed(RouteNames.membership);
    }
  }

  Future<void> showCoinUnlock(
    BuildContext context,
    PlayerFeedItem item, {
    bool launchedByAutoSheet = false,
  }) async {
    final request = _buildRequest(
      channel: PlayerModalChannels.coinUnlock,
      type: AppModalType.coinUnlock,
      payload: PlayerCoinUnlockModalPayload(
        sessionKey: _sessionKey,
        itemId: item.id,
        price: item.episode.requiredCoins,
      ),
    );

    final result = await _modalService.show(request);

    if (PlayerModalResults.isDismissed(result) && launchedByAutoSheet) {
      _tryMarkAutoSheetDismissed(item.id);
    }
    if (!PlayerModalResults.isUnlocked(result)) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    // API解锁已成功，Controller已更新entitlement和feed中的videoUrl
    // 无需再次调用completeCoinUnlock（避免重复扣币）
    // 直接触发播放即可
    final sheetIntent = await _engine.retryPlayback(item);

    if (sheetIntent == PlayerOverlaySheetIntent.none && context.mounted) {
      _appToast.success(context.l10n.playerUnlockSuccessful);
    }
  }

  Future<void> showRechargeUnlock(
    BuildContext context,
    PlayerFeedItem item, {
    bool launchedByAutoSheet = false,
  }) async {
    await _rechargeController.open(
      itemId: item.id,
      requiredCoins: item.episode.requiredCoins,
    );
    if (!context.mounted) {
      return;
    }

    final request = _buildRequest(
      channel: PlayerModalChannels.rechargeUnlock,
      type: AppModalType.recharge,
      payload: PlayerRechargeUnlockModalPayload(
        sessionKey: _sessionKey,
        itemId: item.id,
        requiredCoins: item.episode.requiredCoins,
        dramaId: int.tryParse(item.content.id) ?? 0,
        episodeNo: item.episode.number,
        shortTitle: item.content.playTitle.isNotEmpty
            ? item.content.playTitle
            : item.content.title,
        cover: item.content.posterAssetPath,
        episodeId: int.tryParse(item.episode.id),
      ),
    );

    final result = await _modalService.show(request);

    if (!context.mounted) {
      return;
    }

    if (!PlayerModalResults.isRechargeSuccess(result)) {
      if (launchedByAutoSheet &&
          (PlayerModalResults.isDismissed(result) ||
              PlayerModalResults.isCancelled(result))) {
        _tryMarkAutoSheetDismissed(item.id);
      }
      _rechargeController.close();
      return;
    }

    final rechargeState = _readRechargeState();
    final selectedCoinPackage = rechargeState.selectedCoinPackage;
    final selectedMembershipPackage = rechargeState.selectedMembershipPackage;

    await _engine.grantRechargeSelection(
      selectedCoinPackage: selectedCoinPackage != null,
      selectedMembershipPackage: selectedMembershipPackage != null,
      coinPackageTotalCoins: selectedCoinPackage?.totalCoins,
    );
    if (!context.mounted) {
      return;
    }

    final flowResult = await _engine.continueAfterRechargeSuccess(
      item: item,
      grantedCoinPackage: selectedCoinPackage != null,
      grantedMembershipPackage: selectedMembershipPackage != null,
    );
    if (!context.mounted) {
      return;
    }

    if (flowResult.didActivateMembership) {
      _appToast.success(context.l10n.playerMembershipActivated);
      return;
    }
    if (flowResult.didAutoUnlock) {
      _appToast.success(context.l10n.playerUnlockedAutomatically);
      return;
    }

    await presentSheetIntent(
      context,
      item,
      flowResult.sheetIntent,
      launchedByAutoSheet: launchedByAutoSheet,
    );
  }

  void dismissPlayerModals() {
    _modalService.dismissForSource(AppModalSource.player);
  }

  void _tryMarkAutoSheetDismissed(String itemId) {
    try {
      _overlay.markDismissed(itemId);
    } on Object {
      // Session notifiers may already be disposed during entitlement rebuilds.
    }
  }

  FeatureAppModalRequest _buildRequest({
    required String channel,
    required AppModalType type,
    required Object? payload,
  }) {
    return FeatureAppModalRequest(
      requestId: _modalController.nextRequestId(),
      source: AppModalSource.player,
      channel: channel,
      payload: payload,
      type: type,
      priority: AppModalPriority.high,
      dismissPolicy: AppModalDismissPolicy.standard,
    );
  }
}

final playerUnlockModalCoordinatorProvider =
    Provider.family<PlayerUnlockModalCoordinator, String>((ref, sessionKey) {
      final rechargeProvider = playerRechargeUnlockControllerProvider(
        sessionKey,
      );
      final container = ref.container;
      return PlayerUnlockModalCoordinator(
        sessionKey: sessionKey,
        modalService: ref.watch(appModalServiceProvider),
        modalController: ref.watch(appModalControllerProvider),
        engine: ref.read(playerFeedEngineProvider(sessionKey).notifier),
        overlayOrchestrator: ref.read(
          playerOverlayOrchestratorProvider(sessionKey).notifier,
        ),
        appToast: ref.read(appToastProvider),
        rechargeController: ref.read(rechargeProvider.notifier),
        readRechargeState: () => container.read(rechargeProvider),
      );
    });
