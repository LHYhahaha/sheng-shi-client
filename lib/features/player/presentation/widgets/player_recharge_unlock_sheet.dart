import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/utils/period_iso_parser.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../../domain/player_recharge_unlock_offer.dart';
import '../modal/player_modal_results.dart';
import '../modal/player_payment_method_modal_coordinator.dart';
import 'player_payment_method_sheet.dart';

/// 播放器内充值解锁弹窗。
///
/// 这是 entitlement unlock flow 的一部分，不复用普通 Store 页面：它带着当前剧集
/// requiredCoins 与商品目录上下文；余额展示统一读 EntitlementController，不在 offer 内缓存。
/// 继续 pending unlock。
class PlayerRechargeUnlockSheet extends ConsumerStatefulWidget {
  const PlayerRechargeUnlockSheet({
    required this.sessionKey,
    required this.dramaId,
    required this.episodeNo,
    required this.shortTitle,
    required this.cover,
    required this.episodeId,
    super.key,
  });

  final String sessionKey;
  final int dramaId;
  final int episodeNo;
  final String shortTitle;
  final String cover;
  final int episodeId;

  @override
  ConsumerState<PlayerRechargeUnlockSheet> createState() =>
      _PlayerRechargeUnlockSheetState();
}

class _PlayerRechargeUnlockSheetState
    extends ConsumerState<PlayerRechargeUnlockSheet> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每秒更新一次 UI，以显示最新的倒计时状态
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      // 触发 rebuild 以更新倒计时显示
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _presentPaymentMethod(PlayerPaymentSelection selection) async {
    if (!mounted) {
      return;
    }
    final result = await ref
        .read(playerPaymentMethodModalCoordinatorProvider(widget.sessionKey))
        .showPaymentMethod(sessionKey: widget.sessionKey, selection: selection);
    if (!mounted) {
      return;
    }
    if (PlayerModalResults.isPaymentCompleted(result)) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = playerRechargeUnlockControllerProvider(widget.sessionKey);
    final state = ref.watch(provider);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = math.min(654.0, screenHeight - 72);

    // 获取用户金币余额和所需金币
    final coinBalance = ref.watch(entitlementControllerProvider).coinBalance;
    final requiredCoins = state.offer?.requiredCoins ?? 0;
    final hasEnoughCoins = coinBalance >= requiredCoins;

    final content = state.offer == null
        ? KeyedSubtree(
            key: const ValueKey('player_recharge_loading_sheet'),
            child: _LoadingOrError(state: state),
          )
        : KeyedSubtree(
            key: const ValueKey('player_recharge_offer_sheet'),
            child: _OfferContent(
              sessionKey: widget.sessionKey,
              state: state,
              hasEnoughCoins: hasEnoughCoins,
              coinBalance: coinBalance,
              onClose: () {
                ref.read(provider.notifier).close();
                Navigator.of(context).pop(false);
              },
              onCoinTap: (id) {
                final package = state.offer!.coinPackages
                    .where((package) => package.id == id)
                    .firstOrNull;
                if (package != null) {
                  unawaited(
                    _presentPaymentMethod(PlayerPaymentSelection.coin(package)),
                  );
                }
              },
              onMembershipTap: (id) {
                final package = state.offer!.membershipPackages
                    .where((package) => package.id == id)
                    .firstOrNull;
                if (package != null) {
                  unawaited(
                    _presentPaymentMethod(
                      PlayerPaymentSelection.membership(package),
                    ),
                  );
                }
              },
              onUnlockWithCoin: hasEnoughCoins
                  ? () => _unlockWithCoin(context, ref, state)
                  : null,
            ),
          );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: const Color(0xFF1D1D20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          width: double.infinity,
          child: content,
        ),
      ),
    );
  }

  Future<void> _unlockWithCoin(
    BuildContext context,
    WidgetRef ref,
    PlayerRechargeUnlockState state,
  ) async {
    if (!mounted) return;

    final controller = ref.read(
      playerRechargeUnlockControllerProvider(widget.sessionKey).notifier,
    );

    // 在 async gap 之前保存 navigator，避免 BuildContext 警告
    final navigator = Navigator.of(context);

    await controller.unlockWithCoin(
      autoUnlockNext: false,
      // 可以根据实际需求设置
      coin: state.offer?.requiredCoins ?? 0,
      dramaId: widget.dramaId,
      episodeNo: widget.episodeNo,
      shortTitle: widget.shortTitle,
      cover: widget.cover,
      episodeId: widget.episodeId,
    );

    // 检查解锁是否成功
    if (!mounted) return;

    final newState = ref.read(
      playerRechargeUnlockControllerProvider(widget.sessionKey),
    );
    if (newState.status == PlayerRechargeUnlockStatus.success) {
      navigator.pop(true);
    }
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

class _OfferContent extends ConsumerWidget {
  const _OfferContent({
    required this.sessionKey,
    required this.state,
    required this.hasEnoughCoins,
    required this.coinBalance,
    required this.onClose,
    required this.onCoinTap,
    required this.onMembershipTap,
    this.onUnlockWithCoin,
  });

  final String sessionKey;
  final PlayerRechargeUnlockState state;
  final bool hasEnoughCoins;
  final int coinBalance;
  final VoidCallback onClose;
  final ValueChanged<String> onCoinTap;
  final ValueChanged<String> onMembershipTap;
  final VoidCallback? onUnlockWithCoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = state.offer!;
    final isProcessing = state.status == PlayerRechargeUnlockStatus.processing;
    // 检查用户是否已是会员
    final isMember = ref.watch(entitlementControllerProvider).isMember;

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
                // 如果用户有足够金币，显示"使用金币解锁"按钮
                if (onUnlockWithCoin != null) ...[
                  _CoinUnlockButton(
                    onTap: onUnlockWithCoin!,
                    coinCost: offer.requiredCoins,
                    coinBalance: coinBalance,
                    isProcessing: isProcessing,
                  ),
                  const SizedBox(height: 16),
                  // 分隔线
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                  const SizedBox(height: 16),
                ],
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
                        sessionKey: sessionKey,
                        package: package,
                        selected: state.selectedCoinPackageId == package.id,
                        enabled: !isProcessing,
                        onTap: () => onCoinTap(package.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // 如果用户不是会员，显示会员商品
                if (!isMember)
                  for (final package in offer.membershipPackages) ...[
                    _MembershipPackageCard(
                      key: ValueKey('player_recharge_membership_${package.id}'),
                      sessionKey: sessionKey,
                      package: package,
                      benefits: offer.benefits,
                      selected: state.selectedMembershipPackageId == package.id,
                      enabled: !isProcessing,
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
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                    children: [
                      TextSpan(
                        text: context.l10n.appCommonLegalPrivacyPolicy,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              context.push(RoutePaths.privacyPolicy),
                      ),
                      const TextSpan(text: '    ·    '),
                      TextSpan(
                        text: context.l10n.appCommonLegalTermsOfUse,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              context.push(RoutePaths.userAgreement),
                      ),
                    ],
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

class _CoinUnlockButton extends StatelessWidget {
  const _CoinUnlockButton({
    required this.onTap,
    required this.coinCost,
    required this.coinBalance,
    required this.isProcessing,
  });

  final VoidCallback onTap;
  final int coinCost;
  final int coinBalance;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: isProcessing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/profile/coin.png',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '使用 $coinCost 金币解锁',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
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

class _RechargeHeader extends ConsumerWidget {
  const _RechargeHeader({required this.offer, required this.onClose});

  final PlayerRechargeUnlockOffer offer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlementState = ref.watch(entitlementControllerProvider);
    final totalCoinBalance =
        entitlementState.coinBalance + entitlementState.bonusBalance;
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
                    key: const ValueKey('player_recharge_unlock_balance'),
                    label: '${context.l10n.playerCoinBalance}:',
                    value: totalCoinBalance,
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
  const _InlineCoinMetric({
    required this.label,
    required this.value,
    super.key,
  });

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
  const _CoinCardContent({required this.package, required this.displayPrice});

  final PlayerRechargeCoinPackage package;
  final String displayPrice;

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
              '+${package.bonusCoins}',
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
              displayPrice,
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
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: child,
    );
  }
}

class _CoinPackageCard extends ConsumerWidget {
  const _CoinPackageCard({
    required this.sessionKey,
    required this.package,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String sessionKey;
  final PlayerRechargeCoinPackage package;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayPrice =
        package.iapInfo?.displayPrice ?? package.googlePriceLabel;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Stack(
        key: ValueKey('player_recharge_coin_${package.id}'),
        clipBehavior: Clip.none,
        children: [
          _CoinPackageCardFrame(
            selected: selected,
            child: _CoinCardContent(
              package: package,
              displayPrice: displayPrice,
            ),
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

class _PromoCountdownBadge extends ConsumerWidget {
  const _PromoCountdownBadge({
    required this.sessionKey,
    required this.packageId,
  });

  final String sessionKey;
  final String packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final controller = ref.read(
          playerRechargeUnlockControllerProvider(sessionKey).notifier,
        );
        final remainingSeconds = controller.getPromotionRemainingSeconds(
          packageId,
        );
        final remaining = Duration(seconds: remainingSeconds);

        if (remainingSeconds <= 0) {
          return const SizedBox.shrink();
        }

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
      },
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
  const _MembershipPriceBlock({
    required this.package,
    required this.showPromo,
    this.displayPrice,
    this.displayOriginalPrice,
  });

  final PlayerRechargeMembershipPackage package;
  final bool showPromo;
  final String? displayPrice;
  final String? displayOriginalPrice;

  @override
  Widget build(BuildContext context) {
    final price = displayPrice ?? package.googlePriceLabel;
    final originalPrice = displayOriginalPrice ?? package.originalPriceLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          price,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF51210F),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 25 / 20,
          ),
        ),
        if (showPromo && originalPrice != null)
          Text(
            originalPrice,
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
    this.promoDescription,
    this.displayPrice,
    this.displayOriginalPrice,
  });

  final PlayerRechargeMembershipPackage package;
  final String description;
  final bool showPromo;
  final String? promoDescription;
  final String? displayPrice;
  final String? displayOriginalPrice;

  @override
  Widget build(BuildContext context) {
    final title = PeriodIsoParser.localizedMembershipTitle(
      package.title,
      fallbackId: package.id,
      languageCode: Localizations.localeOf(context).languageCode,
    );
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
                  title,
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
                // 展示促销文案（如果有），否则展示description
                if (promoDescription != null)
                  Text(
                    promoDescription!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF51210F).withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 13 / 10,
                    ),
                  )
                else
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
          _MembershipPriceBlock(
            package: package,
            showPromo: showPromo,
            displayPrice: displayPrice,
            displayOriginalPrice: displayOriginalPrice,
          ),
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

class _MembershipPackageCard extends ConsumerWidget {
  const _MembershipPackageCard({
    super.key,
    required this.sessionKey,
    required this.package,
    required this.benefits,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String sessionKey;
  final PlayerRechargeMembershipPackage package;
  final List<PlayerRechargeBenefit> benefits;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iapInfo = package.iapInfo;
    final displayPrice = iapInfo?.displayPrice ?? package.googlePriceLabel;
    final displayOriginalPrice =
        iapInfo?.displayOriginalPrice ?? package.originalPriceLabel;
    final showPromo = iapInfo?.hasPromo ?? package.isPromotional;

    String? promoDescription;
    if (iapInfo?.hasPromo == true) {
      final locale = Localizations.localeOf(context);
      promoDescription = PeriodIsoParser.buildPromoDescription(
        promoPrice: iapInfo!.displayPrice,
        regularPrice: iapInfo.displayOriginalPrice,
        promoPeriodIso: iapInfo.promoPeriod,
        regularPeriodIso: iapInfo.regularPeriod,
        languageCode: locale.languageCode,
      );
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final description = languageCode == 'en'
        ? package.description ?? context.l10n.playerAutoRenewCancel
        : context.l10n.playerAutoRenewCancel;
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
              showPromo: showPromo,
              promoDescription: promoDescription,
              displayPrice: displayPrice,
              displayOriginalPrice: displayOriginalPrice,
            ),
            _MembershipBenefitBand(benefits: benefits),
            if (showPromo)
              Positioned(
                right: 0,
                top: 0,
                child: _PromoCountdownBadge(
                  sessionKey: sessionKey,
                  packageId: package.id,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
