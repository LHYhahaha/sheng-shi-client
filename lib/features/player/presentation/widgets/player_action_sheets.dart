import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../../entitlement/application/entitlement_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/custom_switch.dart';

class PlayerShareSheet extends StatelessWidget {
  const PlayerShareSheet({
    required this.onFacebookTap,
    required this.onCopyLinkTap,
    super.key,
  });

  final VoidCallback onFacebookTap;
  final VoidCallback onCopyLinkTap;

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 40, height: 40),
              Text(
                context.l10n.playerShare,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 20 / 16,
                ),
              ),
              // const Spacer(),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareTarget(
                color: const Color(0xFF1877F2),
                imageUrl: "share_facebook",
                label: context.l10n.playerFacebook,
                onTap: onFacebookTap,
                iconColor: Colors.white,
              ),
              _ShareTarget(
                color: const Color(0xFF6B6570),
                imageUrl: "share_copy",
                label: context.l10n.shareActionCopyLink,
                onTap: onCopyLinkTap,
              ),
              // _ShareTarget(
              //   color: const Color(0xFF25D366),
              //   icon: Icons.phone_rounded,
              //   label: context.l10n.playerWhatsApp,
              // ),
              // _ShareTarget(
              //   color: const Color(0xFF6F65FF),
              //   icon: Icons.chat_bubble_rounded,
              //   label: context.l10n.playerMessenger,
              // ),
              // _ShareTarget(
              //   color: const Color(0xFFE1306C),
              //   icon: Icons.camera_alt_rounded,
              //   label: context.l10n.playerInstagram,
              // ),
              // _ShareTarget(
              //   color: const Color(0xFFFFFC00),
              //   icon: Icons.bolt_rounded,
              //   label: context.l10n.playerSnapchat,
              //   iconColor: Colors.black,
              // ),
            ],
          ),
          // SingleChildScrollView(
          //   scrollDirection: Axis.horizontal,
          //   physics: const BouncingScrollPhysics(),
          //   child: Row(
          //     children: [
          //       _ShareTarget(
          //         color: const Color(0xFF1877F2),
          //         icon: Icons.facebook_rounded,
          //         label: context.l10n.playerFacebook,
          //         onTap: onFacebookTap,
          //         iconColor: Colors.white,
          //       ),
          //       _ShareTarget(
          //         color: const Color(0xFF6B6570),
          //         icon: Icons.link_rounded,
          //         label: context.l10n.shareActionCopyLink,
          //         onTap: onCopyLinkTap,
          //       ),
          //       // _ShareTarget(
          //       //   color: const Color(0xFF25D366),
          //       //   icon: Icons.phone_rounded,
          //       //   label: context.l10n.playerWhatsApp,
          //       // ),
          //       // _ShareTarget(
          //       //   color: const Color(0xFF6F65FF),
          //       //   icon: Icons.chat_bubble_rounded,
          //       //   label: context.l10n.playerMessenger,
          //       // ),
          //       // _ShareTarget(
          //       //   color: const Color(0xFFE1306C),
          //       //   icon: Icons.camera_alt_rounded,
          //       //   label: context.l10n.playerInstagram,
          //       // ),
          //       // _ShareTarget(
          //       //   color: const Color(0xFFFFFC00),
          //       //   icon: Icons.bolt_rounded,
          //       //   label: context.l10n.playerSnapchat,
          //       //   iconColor: Colors.black,
          //       // ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

class PlayerCoinUnlockSheet extends ConsumerStatefulWidget {
  const PlayerCoinUnlockSheet({
    required this.price,
    required this.balance,
    required this.onConfirm,
    super.key,
  });

  final int price;
  final int balance;
  final Future<void> Function() onConfirm;

  @override
  ConsumerState<PlayerCoinUnlockSheet> createState() =>
      _PlayerCoinUnlockSheetState();
}

class _PlayerCoinUnlockSheetState extends ConsumerState<PlayerCoinUnlockSheet> {
  var _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoUnlockEnabled = ref
        .watch(entitlementControllerProvider)
        .autoUnlockEnabled;
    return _CompactPlayerSheet(
      height: 260,
      child: Column(
        children: [
          Row(
            children: [
              Spacer(),
              _CloseButton(
                key: const ValueKey('player_coin_unlock_close'),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text.rich(
                TextSpan(
                  text: '${context.l10n.playerPrice} ',
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Image.asset(
                        'assets/images/profile/coin.png',
                        width: 16,
                        height: 16,
                      ),
                    ),
                    TextSpan(
                      text: ' ${widget.price}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                key: const ValueKey('player_coin_unlock_price'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 16 / 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Text.rich(
                TextSpan(
                  text: '${context.l10n.playerBalance}: ',
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Image.asset(
                        'assets/images/profile/coin.png',
                        width: 16,
                        height: 16,
                      ),
                    ),
                    TextSpan(
                      text: ' ${widget.balance}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                key: const ValueKey('player_coin_unlock_balance'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 16 / 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AppPrimaryButton(
              key: const ValueKey('player_coin_unlock_confirm'),
              label: context.l10n.playerPlay,
              icon: Icons.play_arrow_rounded,
              onPressed: _isSubmitting ? null : () => unawaited(_submit()),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.autoUnlockNext,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
              SizedBox(width: 27),
              CustomSwitch(
                key: const ValueKey('player_coin_unlock_auto_next_switch'),
                value: autoUnlockEnabled,
                onChanged: (value) {
                  unawaited(
                    ref
                        .read(entitlementControllerProvider.notifier)
                        .setAutoUnlockEnabled(value),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerSpeedSheet extends StatelessWidget {
  const PlayerSpeedSheet({
    required this.selectedRate,
    required this.onRateSelected,
    super.key,
  });

  static const rates = [2.0, 1.5, 1.2, 1.0, 0.8];

  final double selectedRate;
  final ValueChanged<double> onRateSelected;

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: 288,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.playerSpeed,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 20 / 16,
                ),
              ),
              const Spacer(),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 8),
          for (final rate in rates)
            _SpeedOption(
              rate: rate,
              selected: (selectedRate - rate).abs() < 0.01,
              onTap: () {
                onRateSelected(rate);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _SpeedOption extends StatelessWidget {
  const _SpeedOption({
    required this.rate,
    required this.selected,
    required this.onTap,
  });

  final double rate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Text(
              '${rate.toStringAsFixed(1)}x',
              style: TextStyle(
                color: selected ? AppColors.primary : Colors.white,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 20 / 15,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(
                Icons.check_rounded,
                key: ValueKey('player_speed_selected_check'),
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// 旧版居中解锁遮罩，已由 feed chrome 内联 Unlock 与 entitlement sheet 流程替代。
@Deprecated(
  'Use PlayerFeedEngine sheet intents and player chrome unlock controls.',
)
class PlayerPaywallOverlay extends StatelessWidget {
  const PlayerPaywallOverlay({
    required this.label,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.64),
              ),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: SizedBox(
                width: 275,
                height: 44,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.45,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 18 / 14,
                    ),
                  ),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactPlayerSheet extends StatelessWidget {
  const _CompactPlayerSheet({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: const Color(0xFF202123),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({
    required this.color,
    required this.imageUrl,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final Color color;
  final String imageUrl;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Image.asset(
              "assets/images/player/$imageUrl.png",
              width: 56,
              height: 56,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 40,
        child: SvgPicture.asset(
          "assets/images/player/close.svg",
          width: 40,
          height: 40,
        ),
      ),
    );
  }
}
