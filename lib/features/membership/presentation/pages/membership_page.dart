import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/drama_card_exposure.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_service.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';
import '../../../pay/application/payment_loading_controller.dart';
import '../../../pay/domain/member_product_type.dart';
import '../../../player/application/player_entry_preload_coordinator.dart';
import '../../../home/application/vip_only_dramas_provider.dart';
import '../../../home/presentation/widgets/vip_only_dramas_section.dart';
import '../../application/membership_controller.dart';
import '../../application/membership_modal_coordinator.dart';
import '../../domain/membership_plan.dart';
import '../membership_layout.dart';
import '../membership_route_result.dart';
import '../modal/membership_modal_results.dart';
import '../widgets/membership_benefits_panel.dart';
import '../widgets/membership_plan_card.dart';

const _membershipPrimaryTitleGradient = LinearGradient(
  colors: [Color(0xFFFDF5D8), Color(0xFFF2C588)],
);

TextStyle _membershipPrimaryTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ) ??
    const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({
    this.showBackButton = true,
    this.handleBackNavigation = true,
    super.key,
  });

  final bool showBackButton;
  final bool handleBackNavigation;

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  final _dramaExposureSession = Object();
  late final ScrollController _scrollController;
  bool _modalOpen = false;
  bool _showStickyHeader = false;
  late final AppModalService _modalService;
  late final bool _returnToProfile;
  bool _vipDramasRefreshRequested = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _modalService = ref.read(appModalServiceProvider);
    final membershipController = ref.read(
      membershipControllerProvider.notifier,
    );
    unawaited(Future.microtask(membershipController.load));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Member tab 会在切入时统一刷新；独立路由在首次 build 前刷新。
    if (widget.showBackButton && !_vipDramasRefreshRequested) {
      _vipDramasRefreshRequested = true;
      ref.invalidate(vipOnlyDramasProvider);
    }
    if (!_returnToProfileInitialized) {
      final uri = GoRouter.maybeOf(context)?.routeInformationProvider.value.uri;
      _returnToProfile = uri?.queryParameters['returnToProfile'] == 'true';
      _returnToProfileInitialized = true;
    }
  }

  bool _returnToProfileInitialized = false;

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    DramaCardExposure.releasePageSession(_dramaExposureSession);
    _modalService.dismissForSource(AppModalSource.membership);
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final shouldShow =
        _scrollController.offset >=
        MembershipLayout.heroTitleTop - MediaQuery.paddingOf(context).top;
    if (_showStickyHeader != shouldShow) {
      setState(() => _showStickyHeader = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(membershipControllerProvider);
    final controller = ref.read(membershipControllerProvider.notifier);
    final isPaymentLoading = ref.watch(
      paymentLoadingControllerProvider.select((state) => state.isVisible),
    );
    final isPurchaseFlowActive =
        isPaymentLoading ||
        state.confirmationPlan != null ||
        state.purchaseStatus != MembershipPurchaseStatus.idle;
    final topInset = MediaQuery.paddingOf(context).top;
    final l10n = context.l10n;
    final useFloatingPurchaseButton =
        !widget.showBackButton && !widget.handleBackNavigation;

    ref.watch(membershipModalCoordinatorProvider);

    ref.listen(
      membershipControllerProvider.select((state) => state.confirmationPlan),
      (previous, next) {
        if (next == null || _modalOpen) {
          return;
        }

        _modalOpen = true;
        unawaited(
          ref
              .read(membershipModalCoordinatorProvider)
              .presentPurchaseConfirmation(context)
              .then((result) {
                _modalOpen = false;
                if (!mounted) {
                  return;
                }
                if (!context.mounted) {
                  return;
                }
                if (MembershipModalResults.isPurchaseCompleted(result)) {
                  ref
                      .read(membershipControllerProvider.notifier)
                      .hideConfirmation();
                  ref.read(appToastProvider).success(l10n.storePurchaseSuccess);
                  // 根据参数决定导航行为
                  if (_returnToProfile) {
                    // 需要从首页/store等入口进入，购买成功后跳转到"我的"页面
                    if (context.canPop()) {
                      context.pop();
                    }
                    context.go(RoutePaths.profile);
                  } else {
                    // 从播放器充值弹框等入口进入，按原有逻辑返回
                    _goBack(result: MembershipRouteResult.purchaseCompleted);
                  }
                  return;
                }
                final purchaseState = ref.read(membershipControllerProvider);
                final purchaseFailureKind = purchaseState.purchaseFailureKind;
                if (MembershipModalResults.isFailed(result)) {
                  final message =
                      purchaseFailureKind ==
                              MembershipPurchaseFailureKind.orderCreation ||
                          purchaseFailureKind ==
                              MembershipPurchaseFailureKind.verification ||
                          purchaseState.purchaseStatus ==
                              MembershipPurchaseStatus.verifying
                      ? l10n.networkError
                      : l10n.storePurchaseFailed;
                  ref.read(appToastProvider).error(message);
                } else if (MembershipModalResults.isCancelled(result)) {
                  ref.read(appToastProvider).info(l10n.storePurchaseCancelled);
                }
                ref
                    .read(membershipControllerProvider.notifier)
                    .hideConfirmation();
              }),
        );
      },
    );
    ref.listen(
      membershipControllerProvider.select((state) => state.purchaseStatus),
      (previous, next) {
        final purchaseState = ref.read(membershipControllerProvider);
        // 有确认弹框的流程由 modal result 处理；仅直付 Google 在这里收尾。
        if (purchaseState.confirmationPlan != null) {
          return;
        }
        if (next == MembershipPurchaseStatus.success) {
          ref.read(appToastProvider).success(l10n.storePurchaseSuccess);
          _goBack(result: MembershipRouteResult.purchaseCompleted);
        } else if (next == MembershipPurchaseStatus.failed) {
          ref
              .read(appToastProvider)
              .error(
                purchaseState.purchaseFailureKind ==
                        MembershipPurchaseFailureKind.paymentOptions
                    ? l10n.networkError
                    : l10n.storePurchaseFailed,
              );
        } else if (next == MembershipPurchaseStatus.cancelled) {
          ref.read(appToastProvider).info(l10n.storePurchaseCancelled);
        }
      },
    );

    final page = Scaffold(
      backgroundColor: MembershipLayout.background,
      body: Stack(
        children: [
          _MembershipBody(
            state: state,
            controller: controller,
            scrollController: _scrollController,
            title: context.l10n.membershipTitle,
            subtitle: context.l10n.membershipUpgraded,
            topInset: topInset,
            useFloatingPurchaseButton: useFloatingPurchaseButton,
            dramaExposureSession: _dramaExposureSession,
            analytics: ref.read(analyticsServiceProvider),
            onPlanTap: _selectPlan,
          ),
          if (state.hasContent && _showStickyHeader)
            _MembershipStickyHeader(
              title: context.l10n.membershipTitle,
              topInset: topInset,
              hasBackButton: widget.showBackButton,
            ),
          if (widget.showBackButton)
            Positioned(
              top: topInset,
              left: 0,
              child: AppSecondaryPageBackButton(onPressed: _goBack),
            ),
          // 底部悬浮购买按钮
          if (state.hasContent)
            _MembershipBottomButton(
              enabled: state.selectedPlan != null,
              onPurchase: state.selectedPlan == null
                  ? null
                  : () => unawaited(_purchaseSelectedPlan()),
              floating: useFloatingPurchaseButton,
            ),
        ],
      ),
    );

    // Keep the subtree stable when a tab enters/exits payment. Inserting a
    // PopScope only during payment remounts the ListView and resets its offset,
    // while this State still retains the collapsed-header flag.
    return PopScope(
      canPop: !widget.handleBackNavigation && !isPurchaseFlowActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (isPaymentLoading) {
          return;
        }
        if (!widget.handleBackNavigation) {
          return;
        }
        _goBack();
      },
      child: page,
    );
  }

  void _selectPlan(String planId) {
    final plan = ref.read(membershipControllerProvider).planById(planId);
    if (plan == null) {
      return;
    }

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': 'vip_product_card',
              'product_id': plan.id,
              'product_type': _analyticsProductTypeForPlan(plan),
              'position':
                  ref
                      .read(membershipControllerProvider)
                      .plans
                      .indexWhere((item) => item.id == plan.id) +
                  1,
              'payment_click_action': 'select_product',
            }),
          ),
    );
    ref.read(membershipControllerProvider.notifier).selectPlan(planId);
  }

  Future<void> _purchaseSelectedPlan() async {
    final plan = ref.read(membershipControllerProvider).selectedPlan;
    if (plan == null) {
      return;
    }

    final analytics = ref.read(analyticsServiceProvider);
    await ref
        .read(membershipControllerProvider.notifier)
        .purchaseSelectedPlan(
          onPaymentActionResolved: (shouldShowCashier) {
            unawaited(
              analytics.track(
                AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                  'element_name': 'vip_purchase_button',
                  'product_id': plan.id,
                  'product_type': _analyticsProductTypeForPlan(plan),
                  'payment_click_action': shouldShowCashier
                      ? 'open_payment_popup'
                      : 'start_payment',
                }),
              ),
            );
          },
        );
  }

  void _goBack({Object? result}) {
    if (context.canPop()) {
      context.pop(result);
      return;
    }
    context.go(RoutePaths.profile);
  }
}

class _MembershipBody extends StatelessWidget {
  const _MembershipBody({
    required this.state,
    required this.controller,
    required this.scrollController,
    required this.title,
    required this.subtitle,
    required this.topInset,
    required this.useFloatingPurchaseButton,
    required this.dramaExposureSession,
    required this.analytics,
    required this.onPlanTap,
  });

  final MembershipState state;
  final MembershipController controller;
  final ScrollController scrollController;
  final String title;
  final String subtitle;
  final double topInset;
  final bool useFloatingPurchaseButton;
  final Object dramaExposureSession;
  final AnalyticsService analytics;
  final ValueChanged<String> onPlanTap;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: AppPegTopLoader());
    }

    if (state.error != null) {
      return Center(
        child: AppRetryButton(
          onPressed: controller.retry,
          label: context.l10n.retry,
        ),
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: ListView(
        key: const Key('membership_scroll_body'),
        controller: scrollController,
        padding: EdgeInsets.only(
          bottom:
              bottomInset +
              (state.hasContent && !useFloatingPurchaseButton
                  ? MembershipLayout.bottomButtonAreaHeight
                  : 50),
        ),
        physics: const ClampingScrollPhysics(),
        children: [
          SizedBox(
            height: MembershipLayout.planCardsTop,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MembershipHeroBackground(topInset: topInset),
                _MembershipHeroContent(title: title, subtitle: subtitle),
              ],
            ),
          ),
          _MembershipPlanCardsColumn(
            plans: state.plans,
            selectedPlanId: state.selectedPlanId,
            isGoogleBillingUnavailable: state.isGoogleBillingUnavailable,
            onPlanTap: onPlanTap,
          ),
          const SizedBox(height: 16),
          // Padding(
          //   padding: const EdgeInsets.symmetric(
          //     horizontal: MembershipLayout.horizontalPadding,
          //   ),
          //   child: Center(
          //     child: Text(
          //       selectedPlan?.description ?? '',
          //       maxLines: 1,
          //       overflow: TextOverflow.ellipsis,
          //       textAlign: TextAlign.center,
          //       style: Theme.of(context).textTheme.labelMedium?.copyWith(
          //         color: const Color(0xFF767676),
          //         fontSize: 12,
          //         height: 1.5,
          //       ),
          //     ),
          //   ),
          // ),
          SizedBox(
            height:
                MembershipLayout.benefitsPanelTop -
                MembershipLayout.planDescriptionTop -
                18,
          ),
          MembershipBenefitsPanel(
            betweenBenefitsAndTips: VipOnlyDramasSection(
              exposurePageSession: dramaExposureSession,
              exposureAnalytics: analytics,
              listPadding: const EdgeInsets.symmetric(
                horizontal: MembershipLayout.horizontalPadding,
              ),
              onDramaTap: (drama, position) {
                unawaited(
                  ProviderScope.containerOf(context)
                      .read(analyticsServiceProvider)
                      .track(
                        AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                          'element_name': 'drama_card',
                          'drama_id': drama.id,
                          'position': position,
                        }),
                      ),
                );
                preparePlayerEntryPreload(
                  context,
                  dramaId: drama.id,
                  episodeId: '1',
                  trigger: 'membership_vip_only_drama_tap',
                  resumeHint: playerEntryResumeHintFor(drama.watchProgress),
                );
                context.push(
                  RoutePaths.playerLocation(
                    dramaId: drama.id,
                    episodeId: '1',
                    trigger: 'membership_vip_only_drama_tap',
                    userActionAtMs: DateTime.now().millisecondsSinceEpoch,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _analyticsProductTypeForPlan(MembershipPlan plan) =>
    MemberProductType.analyticsProductTypeFor(plan.memberType);

class _MembershipPlanCardsColumn extends StatelessWidget {
  const _MembershipPlanCardsColumn({
    required this.plans,
    required this.selectedPlanId,
    required this.isGoogleBillingUnavailable,
    required this.onPlanTap,
  });

  final List<MembershipPlan> plans;
  final String? selectedPlanId;
  final bool isGoogleBillingUnavailable;
  final void Function(String planId) onPlanTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (plans.isEmpty) {
          return SizedBox(
            height: 120,
            child: Center(
              child: AppEmptyState(
                message: isGoogleBillingUnavailable
                    ? context.l10n.paymentGoogleUnavailable
                    : context.l10n.noData,
                imageSize: 72,
                spacing: 4,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MembershipLayout.horizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < plans.length; index++) ...[
                if (index > 0)
                  const SizedBox(height: MembershipLayout.verticalPlanCardGap),
                MembershipPlanCard(
                  key: MembershipPlanCard.planKey(plans[index].id),
                  plan: plans[index],
                  selected: selectedPlanId == plans[index].id,
                  onTap: () => onPlanTap(plans[index].id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MembershipHeroContent extends StatelessWidget {
  const _MembershipHeroContent({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: MembershipLayout.horizontalPadding,
          right: MembershipLayout.horizontalPadding,
          top: MembershipLayout.heroTitleTop,
          child: IgnorePointer(
            child: ShaderMask(
              shaderCallback: (rect) {
                return _membershipPrimaryTitleGradient.createShader(rect);
              },
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _membershipPrimaryTitleStyle(context),
              ),
            ),
          ),
        ),
        Positioned(
          left: MembershipLayout.horizontalPadding,
          right: MembershipLayout.horizontalPadding,
          top: MembershipLayout.heroSubtitleTop,
          child: IgnorePointer(
            child: Row(
              children: [
                const _AvatarDots(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MembershipStickyHeader extends StatelessWidget {
  const _MembershipStickyHeader({
    required this.title,
    required this.topInset,
    required this.hasBackButton,
  });

  final String title;
  final double topInset;
  final bool hasBackButton;

  @override
  Widget build(BuildContext context) {
    final contentHeight = hasBackButton
        ? MembershipLayout.navButtonSize
        : MembershipLayout.primaryStickyHeaderContentHeight;
    final titleStyle = hasBackButton
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          )
        : _membershipPrimaryTitleStyle(context);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: topInset + contentHeight,
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!hasBackButton)
                const Positioned(
                  left: MembershipLayout.horizontalPadding,
                  child: SizedBox(width: MembershipLayout.navButtonSize),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hasBackButton
                      ? MembershipLayout.navButtonSize
                      : MembershipLayout.horizontalPadding,
                ),
                child: Align(
                  alignment: hasBackButton
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: hasBackButton
                      ? Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        )
                      : ShaderMask(
                          shaderCallback: (rect) =>
                              _membershipPrimaryTitleGradient.createShader(
                                rect,
                              ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipHeroBackground extends StatelessWidget {
  const _MembershipHeroBackground({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: topInset + MembershipLayout.heroBackgroundHeight,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/membership/membership_hero_bg.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.55, 1],
                  colors: [
                    MembershipLayout.background.withValues(alpha: 0.08),
                    MembershipLayout.background.withValues(alpha: 0.35),
                    MembershipLayout.background,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarDots extends StatelessWidget {
  const _AvatarDots();

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFFE6CFA6), Color(0xFFB58E7A), Color(0xFF72564B)];
    const images = [
      "assets/images/membership/1.png",
      "assets/images/membership/2.png",
      "assets/images/membership/3.png",
    ];

    return SizedBox(
      width: 36,
      height: 16,
      child: Stack(
        children: [
          for (var index = 0; index < colors.length; index++)
            Positioned(
              left: index * 10.0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                  image: DecorationImage(image: AssetImage(images[index])),
                  border: Border.all(color: MembershipLayout.background),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 底部悬浮购买按钮
class _MembershipBottomButton extends StatelessWidget {
  const _MembershipBottomButton({
    required this.enabled,
    required this.onPurchase,
    required this.floating,
  });

  final bool enabled;
  final VoidCallback? onPurchase;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (floating) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 16,
        child: Center(
          child: GestureDetector(
            onTap: enabled ? onPurchase : null,
            child: Container(
              width: 247,
              height: 57,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: enabled ? null : const Color(0xFF4A4A4A),
                gradient: enabled
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFEBC7), Color(0xFFFFDB99)],
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.membershipBuyNow,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: enabled
                          ? const Color(0xFF230D06)
                          : Colors.white.withValues(alpha: 0.45),
                      fontSize: 18,
                      fontWeight: FontWeight(590),
                    ),
                  ),
                  Text(
                    context.l10n.membershipAutoRenewCancel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF230D06).withValues(alpha: 0.3),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 12),
        decoration: BoxDecoration(
          color: MembershipLayout.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          border: Border(top: BorderSide(color: Color(0xFF3B3B3B), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: enabled ? onPurchase : null,
              child: Container(
                height: 46,
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: enabled ? null : const Color(0xFF4A4A4A),
                  gradient: enabled
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFEBC7), Color(0xFFFFDB99)],
                        )
                      : null,
                ),
                child: Text(
                  context.l10n.membershipBuyNow,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: enabled
                        ? const Color(0xFF1B1B1C)
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              context.l10n.membershipAutoRenewCancel,
              style: TextStyle(
                color: Color(0XFFFFFFFF).withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
            // RichText(
            //   text: TextSpan(
            //     style: TextStyle(
            //       fontSize: 11,
            //       color: Color(0xFFFFFFFF).withValues(alpha: 0.5),
            //     ),
            //     children: [
            //       TextSpan(
            //         text: context.l10n.appCommonLegalPrivacyPolicy,
            //         recognizer: TapGestureRecognizer()
            //           ..onTap = () => context.push(RoutePaths.privacyPolicy),
            //       ),
            //       TextSpan(text: '    ·    '),
            //       TextSpan(
            //         text: context.l10n.appCommonLegalTermsOfUse,
            //         recognizer: TapGestureRecognizer()
            //           ..onTap = () => context.push(RoutePaths.userAgreement),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
