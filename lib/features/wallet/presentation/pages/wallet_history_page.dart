import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                }
              },
            ),
            Expanded(
              child: _HistoryBody(
                state: state,
                type: widget.type,
                onRetry: controller.retry,
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
  });

  final WalletState state;
  final WalletRecordType type;
  final VoidCallback onRetry;

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

    final records = state.recordsFor(type);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        return _HistoryRecordRow(record: records[index]);
      },
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
