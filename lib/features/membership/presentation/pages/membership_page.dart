import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../application/membership_controller.dart';
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
        backgroundColor: const Color(0xFF0F0F10),
        body: Stack(
          children: [
            _MembershipHeroBackground(topInset: topInset),
            if (state.hasContent)
              _MembershipHeroContent(
                title: state.heroTitle,
                subtitle: state.heroSubtitle,
                topInset: topInset,
              ),
            _MembershipBody(
              state: state,
              controller: controller,
              topInset: topInset,
            ),
            Positioned(
              top: topInset + 4,
              left: 6,
              child: IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: state.hasContent
            ? SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  color: const Color(0xFF151515),
                  child: AppPrimaryButton(
                    label: context.l10n.membershipBuyNow,
                    onPressed: state.selectedPlan == null
                        ? null
                        : controller.showConfirmation,
                  ),
                ),
              )
            : null,
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
  const _MembershipBody({
    required this.state,
    required this.controller,
    required this.topInset,
  });

  final MembershipState state;
  final MembershipController controller;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: TextButton(
          onPressed: controller.retry,
          child: Text(context.l10n.feedLoadFailed),
        ),
      );
    }

    final selectedPlan = state.selectedPlan;

    return Positioned.fill(
      top: topInset + 169,
      child: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 92,
        ),
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF0F0F10)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final plan in state.plans)
                        MembershipPlanCard(
                          plan: plan,
                          selected: state.selectedPlanId == plan.id,
                          onTap: () => controller.selectPlan(plan.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 18,
                    child: Center(
                      child: Text(
                        selectedPlan?.description ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF767676),
                              height: 1.5,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MembershipBenefitsPanel(benefits: state.benefits, tips: state.tips),
        ],
      ),
    );
  }
}

class _MembershipHeroContent extends StatelessWidget {
  const _MembershipHeroContent({
    required this.title,
    required this.subtitle,
    required this.topInset,
  });

  final String title;
  final String subtitle;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: topInset + 83,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  colors: [Color(0xFFFDF5D8), Color(0xFFF2C588)],
                ).createShader(rect);
              },
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const _AvatarDots(),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
      height: topInset + 167,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Image.asset(
                'assets/images/membership/membership_hero_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.41, 1],
                    colors: [
                      const Color(0xFF0F0F10).withValues(alpha: 0.06),
                      const Color(0xFF0F0F10).withValues(alpha: 0.2),
                      const Color(0xFF0F0F10),
                    ],
                  ),
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
              left: index * 10,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F0F10)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
