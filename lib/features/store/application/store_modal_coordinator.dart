import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/app_modal_controller.dart';
import '../../../core/modal/app_modal_policy.dart';
import '../../../core/modal/app_modal_provider.dart';
import '../../../core/modal/app_modal_request.dart';
import '../../../core/modal/app_modal_result.dart';
import '../../../core/modal/app_modal_service.dart';
import '../../../core/modal/app_modal_source.dart';
import '../presentation/modal/store_modal_channels.dart';
import '../presentation/modal/store_modal_payloads.dart';
import 'store_controller.dart';

/// Store 购买确认弹窗编排。
class StoreModalCoordinator {
  StoreModalCoordinator({
    required AppModalService modalService,
    required AppModalController modalController,
    required StoreController storeController,
    required StoreState Function() readStoreState,
  }) : _modalService = modalService,
       _modalController = modalController,
       _storeController = storeController,
       _readStoreState = readStoreState;

  final AppModalService _modalService;
  final AppModalController _modalController;
  final StoreController _storeController;
  final StoreState Function() _readStoreState;

  Future<StorePurchaseModalResult> presentPurchaseConfirmation(
    BuildContext context,
  ) async {
    final package = _readStoreState().confirmationPackage;
    if (package == null || !context.mounted) {
      return const StorePurchaseModalResult.dismissed();
    }

    final request = FeatureAppModalRequest(
      requestId: _modalController.nextRequestId(),
      source: AppModalSource.store,
      channel: StoreModalChannels.purchaseConfirmation,
      type: AppModalType.storeConfirm,
      payload: StorePurchaseModalPayload(packageId: package.id),
      priority: AppModalPriority.high,
    );

    final result = await _modalService.show(request);
    if (result is StorePurchaseModalResult) {
      return result;
    }
    return switch (result.kind) {
      AppModalResultKind.completed =>
        const StorePurchaseModalResult.completed(),
      AppModalResultKind.cancelled =>
        const StorePurchaseModalResult.cancelled(),
      AppModalResultKind.dismissed =>
        const StorePurchaseModalResult.dismissed(),
      AppModalResultKind.failed => const StorePurchaseModalResult.cancelled(),
    };
  }

  void dismissStoreModals() {
    _modalService.dismissForSource(AppModalSource.store);
    _storeController.hideConfirmation();
  }
}

final storeModalCoordinatorProvider = Provider<StoreModalCoordinator>((ref) {
  return StoreModalCoordinator(
    modalService: ref.watch(appModalServiceProvider),
    modalController: ref.watch(appModalControllerProvider),
    storeController: ref.watch(storeControllerProvider.notifier),
    readStoreState: () => ref.read(storeControllerProvider),
  );
});
