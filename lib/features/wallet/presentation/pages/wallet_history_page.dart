import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../application/wallet_controller.dart';
import '../../domain/wallet_record.dart';

class WalletHistoryPage extends ConsumerStatefulWidget {
  const WalletHistoryPage({required this.type, super.key});

  final WalletRecordType type;

  @override
  ConsumerState<WalletHistoryPage> createState() => _WalletHistoryPageState();
}

class _WalletHistoryPageState extends ConsumerState<WalletHistoryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final title = switch (widget.type) {
      WalletRecordType.transaction => context.l10n.transactionHistoryTitle,
      WalletRecordType.consumption => context.l10n.consumptionHistoryTitle,
      WalletRecordType.coins => context.l10n.recordCoinsTitle,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HistoryHeader(
              title: title,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.wallet);
                }
              },
            ),
            Expanded(
              child: _HistoryBody(
                state: state,
                type: widget.type,
                onRetry: controller.retry,
                onConsumptionFilterChanged: controller.setConsumptionFilter,
                onClaimReward: controller.claimReward,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.title, required this.onBack});

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

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.state,
    required this.type,
    required this.onRetry,
    required this.onConsumptionFilterChanged,
    required this.onClaimReward,
  });

  final WalletState state;
  final WalletRecordType type;
  final VoidCallback onRetry;
  final ValueChanged<WalletConsumptionStatus> onConsumptionFilterChanged;
  final ValueChanged<String> onClaimReward;

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

    final records = switch (type) {
      WalletRecordType.consumption =>
        state
            .recordsFor(type)
            .where(
              (record) => record.consumptionStatus == state.consumptionFilter,
            )
            .toList(growable: false),
      _ => state.recordsFor(type),
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        type == WalletRecordType.consumption ? 0 : 12,
        16,
        MediaQuery.paddingOf(context).bottom + 32,
      ),
      children: [
        if (type == WalletRecordType.consumption) ...[
          _ConsumptionSegmentedControl(
            value: state.consumptionFilter,
            onChanged: onConsumptionFilterChanged,
          ),
          const SizedBox(height: 24),
        ],
        if (records.isEmpty)
          const _HistoryEmptyState()
        else
          for (var index = 0; index < records.length; index++) ...[
            switch (type) {
              WalletRecordType.consumption => _ConsumptionRecordRow(
                record: records[index],
              ),
              WalletRecordType.coins => _CoinRewardRecordRow(
                record: records[index],
                onClaim: () => onClaimReward(records[index].id),
              ),
              WalletRecordType.transaction => _HistoryRecordRow(
                record: records[index],
              ),
            },
            if (index != records.length - 1)
              SizedBox(height: type == WalletRecordType.consumption ? 20 : 20),
          ],
      ],
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          context.l10n.walletHistoryEmpty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ConsumptionSegmentedControl extends StatelessWidget {
  const _ConsumptionSegmentedControl({
    required this.value,
    required this.onChanged,
  });

  final WalletConsumptionStatus value;
  final ValueChanged<WalletConsumptionStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: context.l10n.walletSpent,
            selected: value == WalletConsumptionStatus.spent,
            onTap: () => onChanged(WalletConsumptionStatus.spent),
          ),
          _SegmentButton(
            label: context.l10n.walletExpired,
            selected: value == WalletConsumptionStatus.expired,
            onTap: () => onChanged(WalletConsumptionStatus.expired),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsumptionRecordRow extends StatelessWidget {
  const _ConsumptionRecordRow({required this.record});

  final WalletRecord record;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            record.posterAssetPath ?? 'assets/images/my_list/cover_1.png',
            width: 53,
            height: 73,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.subtitle ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.trailingLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            if (record.trailingSubtitle != null)
              Text(
                record.trailingSubtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CoinRewardRecordRow extends StatelessWidget {
  const _CoinRewardRecordRow({required this.record, required this.onClaim});

  final WalletRecord record;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final enabled = record.rewardEnabled && !record.rewardClaimed;

    return Row(
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Image.asset(
            'assets/images/profile/coin.png',
            width: 26,
            height: 26,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 74,
          height: 30,
          child: FilledButton(
            onPressed: enabled ? onClaim : null,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.textPrimary,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.24),
              foregroundColor: const Color(0xFF0A0014),
              disabledForegroundColor: const Color(
                0xFF0A0014,
              ).withValues(alpha: 0.4),
              textStyle: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(height: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(context.l10n.walletCheckIn),
          ),
        ),
      ],
    );
  }
}

class _HistoryRecordRow extends StatelessWidget {
  const _HistoryRecordRow({required this.record});

  final WalletRecord record;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (record.showCoinIcon) ...[
                    Image.asset(
                      'assets/images/profile/coin.png',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                record.dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          record.trailingLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
