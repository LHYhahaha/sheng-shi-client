import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/membership_controller.dart';
import '../../domain/membership_plan.dart';
import '../membership_layout.dart';
import '../widgets/membership_benefits_panel.dart';
import '../widgets/membership_confirmation_sheet.dart';
import '../widgets/membership_plan_card.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(membershipControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(membershipControllerProvider);
    final controller = ref.read(membershipControllerProvider.notifier);
    final topInset = MediaQuery.paddingOf(context).top;

    ref.listen(
      membershipControllerProvider.select((state) => state.confirmationPlan),
      (previous, next) {
        if (next == null || _sheetOpen) {
          return;
        }

        _sheetOpen = true;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) {
            return Consumer(
              builder: (context, ref, child) {
                final sheetState = ref.watch(membershipControllerProvider);
                final sheetController = ref.read(
                  membershipControllerProvider.notifier,
                );
                return MembershipConfirmationSheet(
                  plan: next,
                  status: sheetState.purchaseStatus,
                  onConfirm: sheetController.confirmMockPurchase,
                  onCancel: sheetController.cancelMockPurchase,
                  onClose: () => Navigator.of(context).pop(),
                );
              },
            );
          },
        ).whenComplete(() {
          _sheetOpen = false;
          if (mounted) {
            controller.hideConfirmation();
          }
        });
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _goBack();
      },
      child: Scaffold(
        backgroundColor: MembershipLayout.background,
        body: Stack(
          children: [
            _MembershipHeroBackground(topInset: topInset),
            _MembershipBody(state: state, controller: controller),
            if (state.hasContent)
              _MembershipHeroContent(
                title: state.heroTitle,
                subtitle: state.heroSubtitle,
              ),
            Positioned(
              top: topInset,
              left: MembershipLayout.navButtonLeft,
              child: SizedBox(
                width: MembershipLayout.navButtonSize,
                height: MembershipLayout.navButtonSize,
                child: IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  color: AppColors.textPrimary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.profile);
  }
}

class _MembershipBody extends StatelessWidget {
  const _MembershipBody({required this.state, required this.controller});

  final MembershipState state;
  final MembershipController controller;

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
          child: TextButton(
            onPressed: controller.retry,
            child: Text(context.l10n.feedLoadFailed),
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
      bottom: 0,
      child: ClipRect(
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomInset + 24),
          physics: const ClampingScrollPhysics(),
          children: [
            _MembershipPlanCardsRow(
              plans: state.plans,
              selectedPlanId: state.selectedPlanId,
              onPlanTap: controller.selectPlanAndConfirm,
            ),
            SizedBox(
              height:
                  MembershipLayout.planDescriptionTop -
                  MembershipLayout.planCardsTop -
                  MembershipLayout.planCardHeight,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MembershipLayout.horizontalPadding,
              ),
              child: SizedBox(
                height: 18,
                child: Center(
                  child: Text(
                    selectedPlan?.description ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF767676),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height:
                  MembershipLayout.benefitsPanelTop -
                  MembershipLayout.planDescriptionTop -
                  18,
            ),
            MembershipBenefitsPanel(benefits: state.benefits, tips: state.tips),
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
    const groupWidth = MembershipLayout.planCardGroupWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final useCenteredGroup =
            maxWidth >= groupWidth + MembershipLayout.horizontalPadding * 2;

        final group = SizedBox(
          width: groupWidth,
          child: Row(
            children: [
              for (var index = 0; index < plans.length; index++) ...[
                if (index > 0)
                  const SizedBox(width: MembershipLayout.planCardGap),
                MembershipPlanCard(
                  plan: plans[index],
                  selected: selectedPlanId == plans[index].id,
                  onTap: () => onPlanTap(plans[index].id),
                ),
              ],
            ],
          ),
        );

        if (useCenteredGroup) {
          return Align(alignment: Alignment.center, child: group);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: MembershipLayout.horizontalPadding,
          ),
          child: group,
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
                  border: Border.all(color: MembershipLayout.background),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
