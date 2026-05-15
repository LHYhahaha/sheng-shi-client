import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../../domain/player_recharge_unlock_offer.dart';

/// 播放器内充值解锁弹窗。
///
/// 这是 entitlement unlock flow 的一部分，不复用普通 Store 页面：它带着当前剧集
/// requiredCoins/coinBalance 上下文，并在 mock purchase success 后通知 PlayerPage
/// 继续 pending unlock。
class PlayerRechargeUnlockSheet extends ConsumerStatefulWidget {
  const PlayerRechargeUnlockSheet({required this.sessionKey, super.key});

  final String sessionKey;

  @override
  ConsumerState<PlayerRechargeUnlockSheet> createState() =>
      _PlayerRechargeUnlockSheetState();
}

class _PlayerRechargeUnlockSheetState
    extends ConsumerState<PlayerRechargeUnlockSheet> {
  static const _promotionDuration = Duration(hours: 1);
  static const _promotionTick = Duration(seconds: 1);

  late Duration _promotionRemaining;
  Timer? _timer;
  bool _didPopSuccess = false;

  @override
  void initState() {
    super.initState();
    _promotionRemaining = _promotionDuration;
    _timer = Timer.periodic(_promotionTick, (_) {
      if (!mounted || _promotionRemaining == Duration.zero) {
        return;
      }
      setState(() {
        final next = _promotionRemaining - _promotionTick;
        _promotionRemaining = next.isNegative ? Duration.zero : next;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = playerRechargeUnlockControllerProvider(widget.sessionKey);
    final state = ref.watch(provider);

    ref.listen(provider.select((state) => state.status), (previous, next) {
      if (next == PlayerRechargeUnlockStatus.success && !_didPopSuccess) {
        _didPopSuccess = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    });

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: const Color(0xFF1F1A27),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 560,
          width: double.infinity,
          child: Column(
            children: [
              const SizedBox(height: 8),
              const AppSheetHandle(),
              Expanded(
                child: state.offer == null
                    ? _LoadingOrError(state: state)
                    : _OfferContent(
                        state: state,
                        promotionRemaining: _promotionRemaining,
                        onClose: () {
                          ref.read(provider.notifier).close();
                          Navigator.of(context).pop(false);
                        },
                        onCoinTap: (id) {
                          unawaited(
                            ref.read(provider.notifier).selectCoinPackage(id),
                          );
                        },
                        onMembershipTap: (id) {
                          unawaited(
                            ref
                                .read(provider.notifier)
                                .selectMembershipPackage(id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({required this.state});

  final PlayerRechargeUnlockState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == PlayerRechargeUnlockStatus.failed) {
      return Center(
        child: Text(
          context.l10n.playerUnlockFailed,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
      );
    }
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
}

class _OfferContent extends StatelessWidget {
  const _OfferContent({
    required this.state,
    required this.promotionRemaining,
    required this.onClose,
    required this.onCoinTap,
    required this.onMembershipTap,
  });

  final PlayerRechargeUnlockState state;
  final Duration promotionRemaining;
  final VoidCallback onClose;
  final ValueChanged<String> onCoinTap;
  final ValueChanged<String> onMembershipTap;

  @override
  Widget build(BuildContext context) {
    final offer = state.offer!;
    final isProcessing = state.status == PlayerRechargeUnlockStatus.processing;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.playerRechargeUnlockTitle,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 22 / 18,
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: const SizedBox.square(
                  key: ValueKey('player_recharge_unlock_close'),
                  dimension: 40,
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _UnlockInfo(offer: offer),
          const SizedBox(height: 18),
          _SectionTitle(label: context.l10n.playerCoinPackages),
          const SizedBox(height: 10),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: offer.coinPackages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final package = offer.coinPackages[index];
                return _CoinPackageCard(
                  package: package,
                  selected: state.selectedCoinPackageId == package.id,
                  enabled: !isProcessing,
                  onTap: () => onCoinTap(package.id),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(label: context.l10n.playerMembershipPackages),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: offer.membershipPackages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final package = offer.membershipPackages[index];
                return _MembershipPackageCard(
                  package: package,
                  benefits: offer.benefits,
                  selected: state.selectedMembershipPackageId == package.id,
                  enabled: !isProcessing,
                  promotionRemaining: promotionRemaining,
                  onTap: () => onMembershipTap(package.id),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (isProcessing)
            Row(
              key: const ValueKey('player_recharge_unlock_processing'),
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.playerUnlockProcessing,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else if (state.status == PlayerRechargeUnlockStatus.failed)
            Text(
              context.l10n.playerUnlockFailed,
              style: const TextStyle(color: AppColors.primary, fontSize: 12),
            ),
          const SizedBox(height: 12),
          Text(
            offer.tips,
            key: const ValueKey('player_recharge_unlock_tips'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11,
              height: 15 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockInfo extends StatelessWidget {
  const _UnlockInfo({required this.offer});

  final PlayerRechargeUnlockOffer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player_recharge_unlock_info'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _CoinInfoBlock(
            label: context.l10n.playerRequiredCoins,
            value: offer.requiredCoins,
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          _CoinInfoBlock(
            label: context.l10n.playerCoinBalance,
            value: offer.coinBalance,
          ),
        ],
      ),
    );
  }
}

class _CoinInfoBlock extends StatelessWidget {
  const _CoinInfoBlock({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Image.asset(
                'assets/images/profile/coin.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 5),
              Text(
                '$value',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 18 / 14,
      ),
    );
  }
}

class _CoinPackageCard extends StatelessWidget {
  const _CoinPackageCard({
    required this.package,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PlayerRechargeCoinPackage package;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        key: ValueKey('player_recharge_coin_${package.id}'),
        width: 108,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/profile/coin.png',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${package.baseCoins}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (package.hasBonus) ...[
                  const SizedBox(height: 6),
                  Text(
                    '+${package.bonusCoins} ${context.l10n.playerBonus}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  package.googlePriceLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (package.hasBonus)
              Positioned(
                top: -14,
                right: -12,
                child: Container(
                  key: ValueKey('player_recharge_bonus_${package.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${package.bonusPercent}%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _MembershipPackageCard extends StatelessWidget {
  const _MembershipPackageCard({
    required this.package,
    required this.benefits,
    required this.selected,
    required this.enabled,
    required this.promotionRemaining,
    required this.onTap,
  });

  final PlayerRechargeMembershipPackage package;
  final List<PlayerRechargeBenefit> benefits;
  final bool selected;
  final bool enabled;
  final Duration promotionRemaining;
  final VoidCallback onTap;

  bool get _showPromo =>
      package.isPromotional && promotionRemaining > Duration.zero;

  @override
  Widget build(BuildContext context) {
    final description =
        package.description ?? context.l10n.playerAutoRenewCancel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        key: ValueKey('player_recharge_membership_${package.id}'),
        width: 238,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    package.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_showPromo)
                  Container(
                    key: const ValueKey('player_recharge_promo_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatCountdown(promotionRemaining),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            if (_showPromo) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.playerLimitedOffer,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    package.googlePriceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                if (_showPromo && package.originalPriceLabel != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      package.originalPriceLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 10,
                height: 13 / 10,
              ),
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: benefits
                  .take(4)
                  .map((benefit) => _BenefitChip(benefit: benefit))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.benefit});

  final PlayerRechargeBenefit benefit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 101,
      child: Row(
        children: [
          Icon(_iconFor(benefit.icon), color: AppColors.gold, size: 13),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              benefit.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(PlayerRechargeBenefitIcon icon) {
    return switch (icon) {
      PlayerRechargeBenefitIcon.series => Icons.video_library_rounded,
      PlayerRechargeBenefitIcon.download => Icons.download_rounded,
      PlayerRechargeBenefitIcon.hd => Icons.hd_rounded,
      PlayerRechargeBenefitIcon.points => Icons.stars_rounded,
      PlayerRechargeBenefitIcon.noAds => Icons.block_rounded,
    };
  }
}
