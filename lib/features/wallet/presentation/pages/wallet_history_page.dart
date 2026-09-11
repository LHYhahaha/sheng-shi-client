import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/i18n/ui_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_load_more_indicator.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../../../shared/widgets/app_secondary_page_header.dart';
import '../../application/wallet_controller.dart';
import '../../domain/wallet_record.dart';

extension _WalletUiTextX on AppLocalizations {
  String walletText(UiText text) => resolveUiText(text);
}

class WalletHistoryPage extends ConsumerStatefulWidget {
  const WalletHistoryPage({required this.type, super.key});

  final WalletRecordType type;

  @override
  ConsumerState<WalletHistoryPage> createState() => _WalletHistoryPageState();
}

class _WalletHistoryPageState extends ConsumerState<WalletHistoryPage> {
  late final ScrollController _scrollController;
  bool _didTriggerLoadMoreNearEnd = false;
  bool _initialLoadPending = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    Future.microtask(_loadInitial);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > 240) {
      _didTriggerLoadMoreNearEnd = false;
      return;
    }
    if (_didTriggerLoadMoreNearEnd) {
      return;
    }
    final state = ref.read(walletControllerProvider);
    if (!state.canLoadMore(widget.type)) {
      return;
    }
    _didTriggerLoadMoreNearEnd = true;
    ref.read(walletControllerProvider.notifier).loadMoreRecords(widget.type);
  }

  void _handleLoadMoreStateChanged(bool? previous, bool next) {
    if (next) {
      return;
    }
    _didTriggerLoadMoreNearEnd = false;
    _checkNearEndAfterFrame();
  }

  void _handleInitialLoadingStateChanged(bool? previous, bool next) {
    _didTriggerLoadMoreNearEnd = false;
    if (!next) {
      _checkNearEndAfterFrame();
    }
  }

  void _checkNearEndAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleScroll();
    });
  }

  void _loadInitial() {
    if (!mounted) return;
    _didTriggerLoadMoreNearEnd = false;
    final controller = ref.read(walletControllerProvider.notifier);
    switch (widget.type) {
      case WalletRecordType.transaction:
        controller.loadTransactionRecords();
      case WalletRecordType.consumption:
        controller.loadConsumptionRecords(WalletConsumptionStatus.spent);
      case WalletRecordType.coins:
        controller.loadRewardCoins();
    }
    if (_initialLoadPending) {
      setState(() => _initialLoadPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    ref.listen(
      walletControllerProvider.select((state) => state.isHistoryLoading),
      _handleInitialLoadingStateChanged,
    );
    ref.listen(
      walletControllerProvider.select((state) => state.isHistoryLoadingMore),
      _handleLoadMoreStateChanged,
    );
    final title = switch (widget.type) {
      WalletRecordType.transaction => context.l10n.transactionHistoryTitle,
      WalletRecordType.consumption => context.l10n.consumptionHistoryTitle,
      WalletRecordType.coins => context.l10n.recordCoinsTitle,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0A0014),
      body: SafeArea(
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
            if (widget.type == WalletRecordType.consumption)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _ConsumptionSegmentedControl(
                  value: state.consumptionFilter,
                  onChanged: (value) {
                    if (value == state.consumptionFilter) {
                      return;
                    }
                    controller.setConsumptionFilter(value);
                    controller.loadConsumptionRecords(value);
                  },
                ),
              ),
            Expanded(
              child: _HistoryBody(
                isLoading: _initialLoadPending || state.isHistoryLoading,
                state: state,
                type: widget.type,
                scrollController: _scrollController,
                onRetry: _loadInitial,
                onLoadMoreRetry: () =>
                    controller.loadMoreRecords(widget.type, retry: true),
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
    return AppSecondaryPageHeader(title: title, onBack: onBack);
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.isLoading,
    required this.state,
    required this.type,
    required this.scrollController,
    required this.onRetry,
    required this.onLoadMoreRetry,
    required this.onClaimReward,
  });

  final WalletState state;
  final bool isLoading;
  final WalletRecordType type;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final VoidCallback onLoadMoreRetry;
  final ValueChanged<String> onClaimReward;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(children: [SizedBox(height: 240), AppPegTopLoader()]);
    }

    if (state.historyError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.networkError,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            AppRetryButton(onPressed: onRetry, label: context.l10n.retry),
          ],
        ),
      );
    }

    final records = state.recordsFor(type);
    final hasFooter = records.isNotEmpty;

    if (records.isEmpty) {
      return const _HistoryEmptyState();
    }

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.paddingOf(context).bottom + 32,
      ),
      children: [
        if (records.isEmpty)
          const _HistoryEmptyState()
        else ...[
          for (var index = 0; index < records.length; index++) ...[
            switch (type) {
              WalletRecordType.consumption =>
                records[index].consumptionStatus ==
                        WalletConsumptionStatus.expired
                    ? _ExpiredConsumptionRecordRow(record: records[index])
                    : _ConsumptionRecordRow(record: records[index]),
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
          if (hasFooter) ...[
            const SizedBox(height: 16),
            _HistoryLoadMoreFooter(
              isLoading: state.isHistoryLoadingMore,
              hasMore: state.nextPageTokenFor(type) != null,
              error: state.historyLoadMoreError,
              onRetry: onLoadMoreRetry,
            ),
          ],
        ],
      ],
    );
  }
}

class _HistoryLoadMoreFooter extends StatelessWidget {
  const _HistoryLoadMoreFooter({
    required this.isLoading,
    required this.hasMore,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasMore;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Center(
          child: isLoading
              ? const AppLoadMoreIndicator(padding: EdgeInsets.zero)
              : error != null
              ? AppRetryButton(onPressed: onRetry, label: context.l10n.retry)
              : Text(
                  hasMore ? '' : context.l10n.feedNoMore,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 200),
      child: AppEmptyState(message: context.l10n.walletHistoryEmpty),
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
              fontSize: 14,
              height: 18/14,
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

  /// 构建封面图片
  Widget _buildPosterImage() {
    // 如果有网络图片资源，使用网络图片
    if (record.posterResource != null && record.posterResource!.isNetwork) {
      final url = record.posterResource!.value;
      return AppCachedNetworkImage(
        imageUrl: url,
        width: 61,
        height: 83,
        fit: BoxFit.cover,
      );
    }

    // 否则使用本地图片或默认图片
    return Image.asset(
      record.posterAssetPath ?? 'assets/images/my_list/cover_1.png',
      width: 61,
      height: 83,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorPlaceholder();
      },
    );
  }

  /// 构建加载失败的占位符
  Widget _buildErrorPlaceholder() {
    return Container(
      width: 53,
      height: 73,
      color: Colors.grey[800],
      child: const Icon(
        Icons.broken_image_outlined,
        color: Colors.white54,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _buildPosterImage(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.walletText(record.titleText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight(510),
                  height: 1.5,
                  fontSize: 14
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.subtitleText == null
                    ? ''
                    : context.l10n.walletText(record.subtitleText!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
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
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
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
              context.l10n.walletText(record.trailingLabelText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight(510),
                height: 1.5,
              ),
            ),
            if (record.trailingSubtitle != null)
              Text(
                record.sourceType?.toLowerCase() == 'coins'
                    ? context.l10n.consumptionHistoryCoins
                    : context.l10n.walletText(record.trailingSubtitleText!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ExpiredConsumptionRecordRow extends StatelessWidget {
  const _ExpiredConsumptionRecordRow({required this.record});

  final WalletRecord record;

  String _sourceTypeLabel(BuildContext context) {
    return switch (record.rewardSourceType) {
      2 => context.l10n.claimCoinsTypeSigninBonus,
      3 => context.l10n.claimCoinsTypeTaskBonus,
      4 => context.l10n.claimCoinsTypeRechargeBonus,
      // sourceType 5 (other) is displayed as an admin credit by product rule.
      1 || 5 => context.l10n.claimCoinsTypeAdminBonus,
      _ => context.l10n.claimCoinsName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final secondaryStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.5),
      height: 1.5,
      fontWeight: FontWeight.normal,
    );

    return Row(
      children: [
        Image.asset('assets/images/profile/coin.png', width: 26, height: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // context.l10n.walletText(record.titleText),
                context.l10n.consumptionExpiredReward,
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
                _sourceTypeLabel(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: secondaryStyle,
              ),
              const SizedBox(height: 4),
              Text(
                record.dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: secondaryStyle,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          context.l10n.walletText(record.trailingLabelText),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CoinRewardRecordRow extends StatelessWidget {
  const _CoinRewardRecordRow({required this.record, required this.onClaim});

  final WalletRecord record;
  final VoidCallback onClaim;

  String _sourceTypeLabel(BuildContext context) {
    return switch (record.rewardSourceType) {
      1 || 5 => context.l10n.claimCoinsTypeAdminBonus,
      2 => context.l10n.claimCoinsTypeSigninBonus,
      3 => context.l10n.claimCoinsTypeTaskBonus,
      4 => context.l10n.claimCoinsTypeRechargeBonus,
      _ => context.l10n.claimCoinsName,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/images/profile/coin.png', width: 26, height: 26),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.walletText(record.titleText),
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
                record.validityLabelText == null
                    ? record.dateLabel
                    : context.l10n.walletText(record.validityLabelText!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          _sourceTypeLabel(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.normal,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _HistoryRecordRow extends StatelessWidget {
  const _HistoryRecordRow({required this.record});

  final WalletRecord record;

  /// 根据 memberPeriodType 生成会员标题
  String _getMembershipTitle(BuildContext context) {
    if (record.memberPeriodType == null) {
      return context.l10n.transactionHistoryMembership;
    }

    // 处理可能的枚举格式
    final periodType = record.memberPeriodType!;
    String member = context.l10n.transactionHistoryMembership;
    if (periodType.contains('WEEK')) {
      return '$member(${context.l10n.transactionHistoryWeekly})';
    } else if (periodType.contains('MONTH')) {
      return '$member(${context.l10n.transactionHistoryMonthly})';
    } else if (periodType.contains('QUARTER')) {
      return '$member(${context.l10n.transactionHistoryQuarterly})';
    } else if (periodType.contains('YEAR')) {
      return '$member(${context.l10n.transactionHistoryYearly})';
    } else {
      return member;
    }
  }

  /// 根据 coin 和 bonusCoin 生成金币标题
  String _getCoinTitle(BuildContext context) {
    final coin = record.coin ?? 0;
    final bonusCoin = record.bonusCoin ?? 0;

    if (bonusCoin == 0) {
      return '$coin ${context.l10n.unitCoin}';
    } else {
      return '$coin ${context.l10n.unitCoin} + $bonusCoin';
    }
  }

  /// 获取显示标题
  String _getDisplayTitle(BuildContext context) {
    // 如果 productType 是会员商品
    if (record.productType != null && record.productType!.contains('MEMBER')) {
      return _getMembershipTitle(context);
    }
    // 如果 productType 是金币商品或有 coin/bonusCoin 信息
    else if ((record.productType != null &&
            record.productType!.contains('COIN')) ||
        record.coin != null ||
        record.bonusCoin != null) {
      return _getCoinTitle(context);
    }
    // 否则使用默认标题
    else {
      return record.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _getDisplayTitle(context);
    final displayAmount = record.amountText ?? record.trailingLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
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
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          displayAmount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
