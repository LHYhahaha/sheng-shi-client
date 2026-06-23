import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../application/wallet_controller.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _WalletHeader(
              title: context.l10n.walletTitle,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }

                context.go(RoutePaths.profile);
              },
            ),
            Expanded(
              child: _WalletBody(
                state: state,
                onRetry: controller.retry,
                onTopUp: () => context.push(RoutePaths.store),
                onTransactionHistory: () =>
                    context.push(RoutePaths.transactionHistory),
                onConsumptionHistory: () =>
                    context.push(RoutePaths.consumptionHistory),
                onRecordCoins: () => context.push(RoutePaths.recordCoins),
                onAutoUnlockChanged: controller.setAutoUnlockNextEpisode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

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
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody({
    required this.state,
    required this.onRetry,
    required this.onTopUp,
    required this.onTransactionHistory,
    required this.onConsumptionHistory,
    required this.onRecordCoins,
    required this.onAutoUnlockChanged,
  });

  final WalletState state;
  final VoidCallback onRetry;
  final VoidCallback onTopUp;
  final VoidCallback onTransactionHistory;
  final VoidCallback onConsumptionHistory;
  final VoidCallback onRecordCoins;
  final ValueChanged<bool> onAutoUnlockChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final entitlementState = ref.watch(entitlementControllerProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 33, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: _WalletBalanceColumn(
                amount: entitlementState.coinBalance,
                label: context.l10n.walletCoins,
              ),
            ),
            Expanded(
              child: _WalletBalanceColumn(
                amount: entitlementState.bonusBalance,
                label: context.l10n.walletBonus,
              ),
            ),
          ],
        ),
        const SizedBox(height: 39),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: onTopUp,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            child: Text(context.l10n.walletTopUp),
          ),
        ),
        const SizedBox(height: 28),
        _WalletMenuRow(
          label: context.l10n.walletMenuTransactionHistory,
          onTap: onTransactionHistory,
        ),
        const SizedBox(height: 28),
        _WalletMenuRow(
          label: context.l10n.walletMenuConsumptionHistory,
          onTap: onConsumptionHistory,
        ),
        const SizedBox(height: 28),
        _WalletMenuRow(
          label: context.l10n.walletMenuClaimCoins,
          onTap: onRecordCoins,
        ),
        const SizedBox(height: 28),
        _WalletSwitchRow(
          label: context.l10n.autoUnlockNext,
          value: entitlementState.autoUnlockEnabled,
          onChanged: onAutoUnlockChanged,
        ),
      ],
    );
  }
}

class _WalletBalanceColumn extends StatelessWidget {
  const _WalletBalanceColumn({required this.amount, required this.label});

  final int amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          amount.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFFBFBFBF),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _WalletMenuRow extends StatelessWidget {
  const _WalletMenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.45),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSwitchRow extends StatelessWidget {
  const _WalletSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.textPrimary,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: AppColors.textPrimary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
