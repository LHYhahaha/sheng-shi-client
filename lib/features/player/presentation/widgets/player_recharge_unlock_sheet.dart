import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = math.min(654.0, screenHeight - 72);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: const Color(0xFF1D1D20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          width: double.infinity,
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
                      ref.read(provider.notifier).selectMembershipPackage(id),
                    );
                  },
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
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              92,
              16,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UnlockInfo(offer: offer),
                const SizedBox(height: 19),
                SizedBox(
                  height: 85,
                  child: ListView.separated(
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: offer.coinPackages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
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
                const SizedBox(height: 20),
                for (final package in offer.membershipPackages) ...[
                  _MembershipPackageCard(
                    package: package,
                    benefits: offer.benefits,
                    selected: state.selectedMembershipPackageId == package.id,
                    enabled: !isProcessing,
                    promotionRemaining: promotionRemaining,
                    onTap: () => onMembershipTap(package.id),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
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
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  offer.tips,
                  key: const ValueKey('player_recharge_unlock_tips'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                    height: 18 / 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF40203E), Color(0x001D1D20)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _RechargeHeader(offer: offer, onClose: onClose),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 24,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x001D1D20),
                    const Color(0xFF1D1D20).withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnlockInfo extends StatelessWidget {
  const _UnlockInfo({required this.offer});

  final PlayerRechargeUnlockOffer offer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('player_recharge_unlock_info'),
      height: 1,
    );
  }
}

class _RechargeHeader extends StatelessWidget {
  const _RechargeHeader({required this.offer, required this.onClose});

  final PlayerRechargeUnlockOffer offer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF40203E), Color(0xFF1D1D20)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  _InlineCoinMetric(
                    label: 'Price:',
                    value: offer.requiredCoins,
                  ),
                  const SizedBox(width: 34),
                  _InlineCoinMetric(
                    label: '${context.l10n.playerCoinBalance}:',
                    value: offer.coinBalance,
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: Container(
                      key: const ValueKey('player_recharge_unlock_close'),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.09)),
          ],
        ),
      ),
    );
  }
}

class _InlineCoinMetric extends StatelessWidget {
  const _InlineCoinMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            height: 18 / 14,
          ),
        ),
        const SizedBox(width: 6),
        Image.asset('assets/images/profile/coin.png', width: 16, height: 16),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 18 / 14,
          ),
        ),
      ],
    );
  }
}

class _CoinAmountText extends StatelessWidget {
  const _CoinAmountText({required this.value, required this.fontSize});

  final int value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/profile/coin.png',
          width: fontSize + 2,
          height: fontSize + 2,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _BonusBadge extends StatelessWidget {
  const _BonusBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9E53), Color(0xFFFE1340), Color(0xFFFE3273)],
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      ),
      child: Text(
        '+$percent%',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 15 / 10,
        ),
      ),
    );
  }
}

class _CoinCardContent extends StatelessWidget {
  const _CoinCardContent({required this.package});

  final PlayerRechargeCoinPackage package;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoinAmountText(value: package.baseCoins, fontSize: 18),
          if (package.hasBonus) ...[
            const SizedBox(height: 4),
            Text(
              '+${package.bonusCoins} ${context.l10n.playerBonus}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                height: 13 / 10,
              ),
            ),
          ],
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              package.googlePriceLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPackageCardFrame extends StatelessWidget {
  const _CoinPackageCardFrame({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 85,
      decoration: BoxDecoration(
        color: const Color(0xFF414143).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: selected ? 1.4 : 0,
        ),
      ),
      child: child,
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
      child: Stack(
        key: ValueKey('player_recharge_coin_${package.id}'),
        clipBehavior: Clip.none,
        children: [
          _CoinPackageCardFrame(
            selected: selected,
            child: _CoinCardContent(package: package),
          ),
          if (package.hasBonus)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                key: ValueKey('player_recharge_bonus_${package.id}'),
                child: _BonusBadge(percent: package.bonusPercent),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromoCountdownBadge extends StatelessWidget {
  const _PromoCountdownBadge({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player_recharge_promo_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0xFFFF5964),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      ),
      child: Text(
        _formatCountdown(remaining),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 15 / 10,
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

class _MembershipCardBackground extends StatelessWidget {
  const _MembershipCardBackground({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: selected ? 1.4 : 0,
        ),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFE6BD), Color(0xFFFFECC9), Color(0xFFFFD68E)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipPriceBlock extends StatelessWidget {
  const _MembershipPriceBlock({required this.package, required this.showPromo});

  final PlayerRechargeMembershipPackage package;
  final bool showPromo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          package.googlePriceLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF51210F),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 25 / 20,
          ),
        ),
        if (showPromo && package.originalPriceLabel != null)
          Text(
            package.originalPriceLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF51210F).withValues(alpha: 0.42),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 16 / 12,
              decoration: TextDecoration.lineThrough,
              decorationColor: const Color(0xFF51210F).withValues(alpha: 0.42),
            ),
          ),
      ],
    );
  }
}

class _MembershipInfoArea extends StatelessWidget {
  const _MembershipInfoArea({
    required this.package,
    required this.description,
    required this.showPromo,
  });

  final PlayerRechargeMembershipPackage package;
  final String description;
  final bool showPromo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 17, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF51210F),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 23 / 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF51210F).withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 13 / 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MembershipPriceBlock(package: package, showPromo: showPromo),
        ],
      ),
    );
  }
}

class _BenefitIcon extends StatelessWidget {
  const _BenefitIcon({required this.icon});

  final PlayerRechargeBenefitIcon icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: Color(0xFF9B604E),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(_iconFor(icon), color: const Color(0xFFFFE7C0), size: 12),
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

class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid({required this.benefits});

  final List<PlayerRechargeBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    final visibleBenefits = benefits.take(4).toList();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleBenefits.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 22,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final benefit = visibleBenefits[index];
        return Row(
          children: [
            _BenefitIcon(icon: benefit.icon),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                benefit.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF77442E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 16 / 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MembershipBenefitBand extends StatelessWidget {
  const _MembershipBenefitBand({required this.benefits});

  final List<PlayerRechargeBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF9DBB0).withValues(alpha: 0.78),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        ),
        child: _BenefitGrid(benefits: benefits),
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
      child: SizedBox(
        key: ValueKey('player_recharge_membership_${package.id}'),
        width: double.infinity,
        height: 159,
        child: Stack(
          children: [
            Positioned.fill(
              child: _MembershipCardBackground(selected: selected),
            ),
            _MembershipInfoArea(
              package: package,
              description: description,
              showPromo: _showPromo,
            ),
            _MembershipBenefitBand(benefits: benefits),
            if (_showPromo)
              Positioned(
                right: 0,
                top: 0,
                child: _PromoCountdownBadge(remaining: promotionRemaining),
              ),
          ],
        ),
      ),
    );
  }
}
