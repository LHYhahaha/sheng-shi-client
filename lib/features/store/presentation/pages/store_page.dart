import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_service.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../application/store_controller.dart';
import '../../application/store_modal_coordinator.dart';
import '../widgets/store_coin_package_card.dart';
import '../widgets/store_tips.dart';
import '../widgets/store_vip_package_card.dart';

class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  bool _modalOpen = false;
  bool _returnedAfterPurchase = false;
  late final AppModalService _modalService;

  @override
  void initState() {
    super.initState();
    _modalService = ref.read(appModalServiceProvider);
    Future.microtask(() => ref.read(storeControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _modalService.dismissForSource(AppModalSource.store);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(storeControllerProvider);
    final controller = ref.read(storeControllerProvider.notifier);

    ref.watch(storeModalCoordinatorProvider);

    ref.listen(
      storeControllerProvider.select((state) => state.confirmationPackage),
      (previous, next) {
        if (next == null || _modalOpen) {
          return;
        }

        _modalOpen = true;
        unawaited(
          ref
              .read(storeModalCoordinatorProvider)
              .presentPurchaseConfirmation(context)
              .whenComplete(() {
                _modalOpen = false;
                if (mounted) {
                  ref.read(storeControllerProvider.notifier).hideConfirmation();
                }
              }),
        );
      },
    );

    // 验单成功后关闭确认弹窗并返回上一页。
    ref.listen(
      storeControllerProvider.select((state) => state.purchaseStatus),
      (previous, next) {
        if (next == StorePurchaseStatus.success &&
            previous != StorePurchaseStatus.success &&
            !_returnedAfterPurchase &&
            mounted) {
          _returnedAfterPurchase = true;
          unawaited(_returnAfterPurchaseSuccess());
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF040404),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -121,
              left: -8,
              child: _StoreGlow(
                width: 338,
                height: 215,
                color: AppColors.primary.withValues(alpha: 0.28),
              ),
            ),
            Positioned(
              top: -121,
              left: -94,
              child: _StoreGlow(
                width: 287,
                height: 215,
                color: const Color(0xFF75154A).withValues(alpha: 0.35),
              ),
            ),
            Column(
              children: [
                _StoreHeader(
                  title: l10n.storeTitle,
                  restoreLabel: l10n.storeRestore,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RoutePaths.profile);
                    }
                  },
                  onRestore: () {
                    ref
                        .read(appToastProvider)
                        .info(l10n.storeRestoreUnavailable);
                  },
                ),
                Expanded(
                  child: _StoreBody(
                    state: state,
                    onRetry: controller.retry,
                    onSelect: controller.selectPackage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: state.hasContent
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                color: const Color(0xFF040404),
                child: AppPrimaryButton(
                  label: l10n.storeBuyNow,
                  onPressed: state.selectedPackage == null
                      ? null
                      : controller.showConfirmation,
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _returnAfterPurchaseSuccess() async {
    _modalService.dismissForSource(AppModalSource.store);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.profile);
    }
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({
    required this.title,
    required this.restoreLabel,
    required this.onBack,
    required this.onRestore,
  });

  final String title;
  final String restoreLabel;
  final VoidCallback onBack;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              color: AppColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(
              width: 58,
              child: TextButton(
                onPressed: onRestore,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: const Color(0x99F2F2F2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(58, 40),
                ),
                child: Text(
                  restoreLabel,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0x99F2F2F2),
                    height: 1.5,
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

class _StoreBody extends StatelessWidget {
  const _StoreBody({
    required this.state,
    required this.onRetry,
    required this.onSelect,
  });

  final StoreState state;
  final VoidCallback onRetry;
  final ValueChanged<String> onSelect;

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
          onPressed: onRetry,
          child: Text(context.l10n.feedLoadFailed),
        ),
      );
    }

    final tips = state.tips;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SizedBox(
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: state.coinPackages.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final package = state.coinPackages[index];
              return StoreCoinPackageCard(
                package: package,
                selected: state.selectedPackageId == package.id,
                onTap: () => onSelect(package.id),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        for (final package in state.vipPackages) ...[
          StoreVipPackageCard(
            package: package,
            selected: state.selectedPackageId == package.id,
            onTap: () => onSelect(package.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (tips != null) ...[
          const SizedBox(height: 4),
          StoreTipsSection(tips: tips),
        ],
      ],
    );
  }
}

class _StoreGlow extends StatelessWidget {
  const _StoreGlow({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 90, spreadRadius: 22),
          ],
        ),
      ),
    );
  }
}
