import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_service.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../../pay/application/payment_loading_controller.dart';
import '../../application/membership_controller.dart';
import '../../application/membership_modal_coordinator.dart';
import '../../domain/membership_plan.dart';
import '../../../../core/utils/period_iso_parser.dart';
import '../membership_layout.dart';
import '../membership_route_result.dart';
import '../modal/membership_modal_results.dart';
import '../widgets/membership_benefits_panel.dart';
import '../widgets/membership_plan_card.dart';

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
  bool _modalOpen = false;
  late final AppModalService _modalService;
  late final bool _returnToProfile;

  @override
  void initState() {
    super.initState();
    _modalService = ref.read(appModalServiceProvider);
    final membershipController = ref.read(
      membershipControllerProvider.notifier,
    );
    unawaited(Future.microtask(membershipController.load));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_returnToProfileInitialized) {
      final uri = GoRouter.maybeOf(context)?.routeInformationProvider.value.uri;
      _returnToProfile = uri?.queryParameters['returnToProfile'] == 'true';
      _returnToProfileInitialized = true;
    }
  }

  bool _returnToProfileInitialized = false;

  @override
  void dispose() {
    _modalService.dismissForSource(AppModalSource.membership);
    super.dispose();
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

    final page = Scaffold(
      backgroundColor: MembershipLayout.background,
      body: Stack(
        children: [
          _MembershipHeroBackground(topInset: topInset),
          _MembershipBody(
            state: state,
            controller: controller,
            useFloatingPurchaseButton: useFloatingPurchaseButton,
          ),
          if (state.hasContent)
            _MembershipHeroContent(
              title: context.l10n.membershipTitle,
              subtitle: context.l10n.membershipUpgraded,
            ),
          if (widget.showBackButton)
            Positioned(
              top: topInset,
              left: 0,
              child: SizedBox(
                width: MembershipLayout.navButtonSize,
                height: MembershipLayout.navButtonSize,
                child: IconButton(
                  onPressed: () => _goBack(),
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  color: AppColors.textPrimary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          // 底部悬浮购买按钮
          if (state.hasContent)
            _MembershipBottomButton(
              enabled: state.selectedPlan != null,
              onPurchase: state.selectedPlan == null
                  ? null
                  : controller.showConfirmation,
              floating: useFloatingPurchaseButton,
            ),
        ],
      ),
    );

    if (!widget.handleBackNavigation && !isPurchaseFlowActive) {
      return page;
    }

    return PopScope(
      canPop: false,
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
    required this.useFloatingPurchaseButton,
  });

  final MembershipState state;
  final MembershipController controller;
  final bool useFloatingPurchaseButton;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return Positioned(
        left: 0,
        right: 0,
        top: MembershipLayout.scrollContentTop,
        bottom: 0,
        child: const Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (state.error != null) {
      return Positioned(
        left: 0,
        right: 0,
        top: MembershipLayout.scrollContentTop,
        bottom: 0,
        child: Center(
          child: AppRetryButton(
            onPressed: controller.retry,
            label: context.l10n.retry,
          ),
        ),
      );
    }

    final selectedPlan = state.selectedPlan;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      key: const Key('membership_scroll_body'),
      left: 0,
      right: 0,
      top: MembershipLayout.scrollContentTop,
      bottom: state.hasContent && !useFloatingPurchaseButton
          ? MembershipLayout.bottomButtonAreaHeight
          : 30,
      child: ClipRect(
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomInset + 24),
          physics: const ClampingScrollPhysics(),
          children: [
            _MembershipPlanCardsRow(
              plans: state.plans,
              selectedPlanId: state.selectedPlanId,
              onPlanTap: controller.selectPlan,
            ),
            // 促销文案（根据语言动态组装）
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final locale = Localizations.localeOf(context);
                final plan = selectedPlan;
                // 只有当 hasPromo 为 true 时才显示促销文案
                final promoText = (plan != null && plan.hasPromo)
                    ? PeriodIsoParser.buildPromoDescription(
                        promoPrice: plan.promotionPriceLabel,
                        regularPrice: plan.regularPriceLabel,
                        promoPeriodIso: plan.promoPeriodIso,
                        regularPeriodIso: plan.regularPeriodIso,
                        languageCode: locale.languageCode,
                      )
                    : null;
                if (promoText == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MembershipLayout.horizontalPadding,
                  ),
                  child: Text(
                    promoText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF767676).withValues(alpha: 0.9),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
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
            MembershipBenefitsPanel(),
          ],
        ),
      ),
    );
  }
}

class _MembershipPlanCardsRow extends StatelessWidget {
  const _MembershipPlanCardsRow({
    required this.plans,
    required this.selectedPlanId,
    required this.onPlanTap,
  });

  final List<MembershipPlan> plans;
  final String? selectedPlanId;
  final void Function(String planId) onPlanTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const visibleCardCount = 3;
        const visibleGapCount = 3;
        final contentWidth =
            constraints.maxWidth - MembershipLayout.horizontalPadding * 2;
        final cardWidth =
            (contentWidth - MembershipLayout.planCardGap * visibleGapCount) /
            visibleCardCount;
        final cardHeight =
            cardWidth *
            MembershipLayout.planCardHeight /
            MembershipLayout.planCardWidth;

        if (plans.isEmpty) {
          return SizedBox(
            height: cardHeight,
            child: Center(
              child: AppEmptyState(
                message: context.l10n.noData,
                imageSize: 72,
                spacing: 4,
              ),
            ),
          );
        }

        return SizedBox(
          height: cardHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: MembershipLayout.horizontalPadding,
            ),
            child: Row(
              children: [
                for (var index = 0; index < plans.length; index++) ...[
                  if (index > 0)
                    const SizedBox(width: MembershipLayout.planCardGap),
                  MembershipPlanCard(
                    key: MembershipPlanCard.planKey(plans[index].id),
                    plan: plans[index],
                    selected: selectedPlanId == plans[index].id,
                    width: cardWidth,
                    height: cardHeight,
                    onTap: () => onPlanTap(plans[index].id),
                  ),
                ],
              ],
            ),
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
                return const LinearGradient(
                  colors: [Color(0xFFFDF5D8), Color(0xFFF2C588)],
                ).createShader(rect);
              },
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
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
              fit: BoxFit.cover,
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
      width: 32,
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
              width: 192,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.membershipAutoRenewCancel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF230D06).withValues(alpha: 0.3),
                      fontSize: 11,
                      height: 1,
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
            Text(
              context.l10n.membershipAutoRenewCancel,
              style: TextStyle(
                color: Color(0XFFE6CFA6).withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
            SizedBox(height: 20),
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
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFFFFFF).withValues(alpha: 0.5),
                ),
                children: [
                  TextSpan(
                    text: context.l10n.appCommonLegalPrivacyPolicy,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.push(RoutePaths.privacyPolicy),
                  ),
                  TextSpan(text: '    ·    '),
                  TextSpan(
                    text: context.l10n.appCommonLegalTermsOfUse,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.push(RoutePaths.userAgreement),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
