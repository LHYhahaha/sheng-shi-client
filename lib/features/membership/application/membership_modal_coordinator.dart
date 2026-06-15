import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/app_modal_controller.dart';
import '../../../core/modal/app_modal_policy.dart';
import '../../../core/modal/app_modal_provider.dart';
import '../../../core/modal/app_modal_request.dart';
import '../../../core/modal/app_modal_result.dart';
import '../../../core/modal/app_modal_service.dart';
import '../../../core/modal/app_modal_source.dart';
import '../presentation/modal/membership_modal_channels.dart';
import '../presentation/modal/membership_modal_payloads.dart';
import 'membership_controller.dart';

/// Membership 购买确认弹窗编排。
class MembershipModalCoordinator {
  MembershipModalCoordinator({
    required AppModalService modalService,
    required AppModalController modalController,
    required MembershipController membershipController,
    required MembershipState Function() readMembershipState,
  }) : _modalService = modalService,
       _modalController = modalController,
       _membershipController = membershipController,
       _readMembershipState = readMembershipState;

  final AppModalService _modalService;
  final AppModalController _modalController;
  final MembershipController _membershipController;
  final MembershipState Function() _readMembershipState;

  Future<MembershipPurchaseModalResult> presentPurchaseConfirmation(
    BuildContext context,
  ) async {
    final plan = _readMembershipState().confirmationPlan;
    if (plan == null || !context.mounted) {
      return const MembershipPurchaseModalResult.dismissed();
    }

    final request = FeatureAppModalRequest(
      requestId: _modalController.nextRequestId(),
      source: AppModalSource.membership,
      channel: MembershipModalChannels.purchaseConfirmation,
      type: AppModalType.membershipPurchase,
      payload: MembershipPurchaseModalPayload(planId: plan.id),
      priority: AppModalPriority.high,
    );

    final result = await _modalService.show(request);
    if (result is MembershipPurchaseModalResult) {
      return result;
    }
    return switch (result.kind) {
      AppModalResultKind.completed =>
        const MembershipPurchaseModalResult.completed(),
      AppModalResultKind.cancelled =>
        const MembershipPurchaseModalResult.cancelled(),
      AppModalResultKind.dismissed =>
        const MembershipPurchaseModalResult.dismissed(),
      AppModalResultKind.failed =>
        const MembershipPurchaseModalResult.cancelled(),
    };
  }

  void dismissMembershipModals() {
    _modalService.dismissForSource(AppModalSource.membership);
    _membershipController.hideConfirmation();
  }
}

final membershipModalCoordinatorProvider = Provider<MembershipModalCoordinator>(
  (ref) {
    return MembershipModalCoordinator(
      modalService: ref.watch(appModalServiceProvider),
      modalController: ref.watch(appModalControllerProvider),
      membershipController: ref.watch(membershipControllerProvider.notifier),
      readMembershipState: () => ref.read(membershipControllerProvider),
    );
  },
);
