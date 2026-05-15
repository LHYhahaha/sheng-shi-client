import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../../../shared/widgets/app_primary_button.dart';

class PlayerShareSheet extends StatelessWidget {
  const PlayerShareSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.playerShare,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 20 / 16,
                ),
              ),
              const Spacer(),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 22),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _ShareTarget(
                  color: const Color(0xFF1877F2),
                  icon: Icons.facebook_rounded,
                  label: context.l10n.playerFacebook,
                ),
                _ShareTarget(
                  color: const Color(0xFF25D366),
                  icon: Icons.phone_rounded,
                  label: context.l10n.playerWhatsApp,
                ),
                _ShareTarget(
                  color: const Color(0xFF6F65FF),
                  icon: Icons.chat_bubble_rounded,
                  label: context.l10n.playerMessenger,
                ),
                _ShareTarget(
                  color: const Color(0xFFE1306C),
                  icon: Icons.camera_alt_rounded,
                  label: context.l10n.playerInstagram,
                ),
                _ShareTarget(
                  color: const Color(0xFFFFFC00),
                  icon: Icons.bolt_rounded,
                  label: context.l10n.playerSnapchat,
                  iconColor: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerUnlockSheet extends StatefulWidget {
  const PlayerUnlockSheet({super.key});

  @override
  State<PlayerUnlockSheet> createState() => _PlayerUnlockSheetState();
}

class _PlayerUnlockSheetState extends State<PlayerUnlockSheet> {
  bool _autoNext = true;

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: 260,
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  text: '${context.l10n.playerPrice} ',
                  children: const [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.monetization_on,
                        color: AppColors.gold,
                        size: 14,
                      ),
                    ),
                    TextSpan(text: ' 60'),
                  ],
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  text: '${context.l10n.playerBalance} ',
                  children: const [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.monetization_on,
                        color: AppColors.gold,
                        size: 14,
                      ),
                    ),
                    TextSpan(text: ' 60'),
                  ],
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
              const SizedBox(width: 12),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 30),
          AppPrimaryButton(
            label: context.l10n.playerPlay,
            icon: Icons.play_arrow_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.playerAutoNext,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _autoNext,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: (value) => setState(() => _autoNext = value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerCoinUnlockSheet extends StatelessWidget {
  const PlayerCoinUnlockSheet({
    required this.price,
    required this.balance,
    required this.onConfirm,
    super.key,
  });

  final int price;
  final int balance;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: 260,
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  text: '${context.l10n.playerPrice} ',
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.monetization_on,
                        color: AppColors.gold,
                        size: 14,
                      ),
                    ),
                    TextSpan(text: ' $price'),
                  ],
                ),
                key: const ValueKey('player_coin_unlock_price'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  text: '${context.l10n.playerBalance} ',
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        Icons.monetization_on,
                        color: AppColors.gold,
                        size: 14,
                      ),
                    ),
                    TextSpan(text: ' $balance'),
                  ],
                ),
                key: const ValueKey('player_coin_unlock_balance'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
              const SizedBox(width: 12),
              _CloseButton(onTap: () => Navigator.of(context).pop(false)),
            ],
          ),
          const SizedBox(height: 30),
          AppPrimaryButton(
            key: const ValueKey('player_coin_unlock_confirm'),
            label: context.l10n.playerPlay,
            icon: Icons.play_arrow_rounded,
            onPressed: onConfirm,
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.playerAutoNext,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
              ),
              Switch.adaptive(
                key: const ValueKey('player_coin_unlock_auto_next_switch'),
                value: true,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: (_) {},
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
              const SizedBox(height: 8),
              const AppSheetHandle(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
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
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 25),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 12 / 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 40,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
