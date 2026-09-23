import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../../../entitlement/application/entitlement_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/custom_switch.dart';
import '../../domain/player_video_quality.dart';

enum PlayerPlaybackSettingsDestination { language, quality }

class PlayerPlaybackSettingsSheet extends StatelessWidget {
  const PlayerPlaybackSettingsSheet({
    required this.languageLabel,
    required this.qualityLabel,
    required this.canShowLanguage,
    required this.canShowQuality,
    super.key,
  });

  final String languageLabel;
  final String qualityLabel;
  final bool canShowLanguage;
  final bool canShowQuality;

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      // height: canShowLanguage && canShowQuality ? 194 : 144,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(height: 40.w, width: 40.w),
              Expanded(
                child: Text(
                  context.l10n.playerSettingsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight(510),
                  ),
                ),
              ),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          SizedBox(height: 12.w),
          Container(
            padding: EdgeInsets.symmetric(vertical: 18.w, horizontal: 16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(24.w),
            ),
            child: Column(
              children: [
                if (canShowLanguage)
                  _SettingsRow(
                    key: const ValueKey('player_settings_language'),
                    iconAsset: 'assets/images/player/player_cc.png',
                    label: context.l10n.playerSubtitleEntry,
                    value: languageLabel,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(PlayerPlaybackSettingsDestination.language),
                  ),
                if (canShowLanguage && canShowQuality) SizedBox(height: 32.w),
                if (canShowQuality)
                  _SettingsRow(
                    key: const ValueKey('player_settings_quality'),
                    iconAsset: 'assets/images/player/player_hdr.png',
                    label: context.l10n.playerSettingsQuality,
                    value: qualityLabel,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(PlayerPlaybackSettingsDestination.quality),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerLanguageSheet extends StatelessWidget {
  const PlayerLanguageSheet({
    required this.options,
    required this.selectedCode,
    required this.onSelected,
    this.showCloseSubtitleOption = false,
    super.key,
  });

  final List<({String label, String code})> options;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;

  /// Only external subtitles can be disabled independently. Embedded subtitle
  /// sources represent video renditions, so they must never expose this row.
  final bool showCloseSubtitleOption;

  @override
  Widget build(BuildContext context) {
    return _PlayerSelectionSheet(
      title: context.l10n.playerSubtitleEntry,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: options.length + (showCloseSubtitleOption ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(height: 3.w),
        itemBuilder: (context, index) {
          if (showCloseSubtitleOption && index == 0) {
            return _SelectionRow(
              key: const ValueKey('player_language_off'),
              label: context.l10n.playerSubtitleOff,
              selected: selectedCode == null,
              onTap: () {
                Navigator.of(context).pop();
                onSelected(null);
              },
            );
          }
          final option = options[index - (showCloseSubtitleOption ? 1 : 0)];
          final selected = _sameCode(option.code, selectedCode);
          return _SelectionRow(
            key: ValueKey('player_language_${option.code}'),
            label: option.label,
            selected: selected,
            onTap: () {
              Navigator.of(context).pop();
              onSelected(option.code);
            },
          );
        },
      ),
    );
  }
}

class PlayerQualitySheet extends StatelessWidget {
  const PlayerQualitySheet({
    required this.qualities,
    required this.selectedQualityId,
    required this.isMember,
    this.isLoading = false,
    required this.onSelected,
    super.key,
  });

  final List<PlayerVideoQuality> qualities;
  final String selectedQualityId;
  final bool isMember;
  final bool isLoading;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSingleQuality = qualities.length == 1;
    return _PlayerSelectionSheet(
      title: context.l10n.playerSettingsQuality,
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.separated(
              shrinkWrap: true,
              itemCount: qualities.length + (isSingleQuality ? 0 : 1),
              separatorBuilder: (_, _) => SizedBox(height: 3.w),
              itemBuilder: (context, index) {
                if (!isSingleQuality && index == 0) {
                  return _SelectionRow(
                    key: const ValueKey('player_quality_auto'),
                    label: context.l10n.playerQualityAuto,
                    selected:
                        selectedQualityId == PlayerVideoQuality.automaticId,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(PlayerVideoQuality.automaticId);
                    },
                  );
                }
                final quality = qualities[index - (isSingleQuality ? 0 : 1)];
                final memberOnly =
                    quality.isMemberOnly && qualities.length > 1 && !isMember;
                final selected =
                    !memberOnly &&
                    (selectedQualityId == quality.id ||
                        (isSingleQuality &&
                            selectedQualityId ==
                                PlayerVideoQuality.automaticId));
                return _SelectionRow(
                  key: ValueKey('player_quality_${quality.id}'),
                  label: quality.label,
                  // A sole rendition is the actual result of Auto as well,
                  // so it should carry the selected state instead of adding
                  // a redundant Auto row.
                  selected: selected,
                  memberOnly: memberOnly,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelected(quality.id);
                  },
                );
              },
            ),
    );
  }
}

class _PlayerSelectionSheet extends StatelessWidget {
  const _PlayerSelectionSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => _CompactPlayerSheet(
    height: MediaQuery.sizeOf(context).height * .52,
    scaleHeight: false,
    child: Column(
      children: [
        Row(
          children: [
            SizedBox(width: 40.w, height: 40.w),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18.sp),
              ),
            ),
            _CloseButton(onTap: () => Navigator.of(context).pop()),
          ],
        ),
        SizedBox(height: 18.w),
        Expanded(child: child),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required super.key,
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24.w),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          Image.asset(iconAsset, width: 20.w, height: 20.w),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .50),
              fontSize: 16.sp,
            ),
          ),
          SizedBox(width: 3.w),
          Image.asset(
            "assets/images/common/white_right.png",
            height: 20.w,
            width: 20.w,
            color: Colors.white.withValues(alpha: .5),
          ),
        ],
      ),
    ),
  );
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.memberOnly = false,
  });

  final String label;
  final bool selected;
  final bool memberOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22.w),
    child: Container(
      height: 56.w,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2C2C2E) : Colors.transparent,
        borderRadius: BorderRadius.circular(24.w),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: memberOnly
                    ? const Color(0xFFF5D28A)
                    : Colors.white.withValues(alpha: selected ? 1 : .5),
                fontSize: 16.sp,
              ),
            ),
          ),
          if (memberOnly) SizedBox(width: 7.w),
          if (memberOnly)
            Image.asset(
              'assets/images/player/player_vip.png',
              width: 16.w,
              height: 16.w,
            ),
          const Spacer(),
          if (selected)
            Icon(Icons.check_rounded, color: Colors.white, size: 21.w),
        ],
      ),
    ),
  );
}

bool _sameCode(String first, String? second) =>
    second != null && first.trim().toLowerCase() == second.trim().toLowerCase();

class PlayerShareSheet extends StatelessWidget {
  const PlayerShareSheet({
    required this.shareHint,
    required this.onFacebookTap,
    required this.onCopyLinkTap,
    super.key,
  });

  final String shareHint;
  final VoidCallback onFacebookTap;
  final VoidCallback onCopyLinkTap;

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: 270,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 40.w, height: 40.w),
              Text(
                context.l10n.playerShare,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  height: 20 / 16,
                ),
              ),
              // const Spacer(),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          SizedBox(height: 16.w),
          _ShareHintBanner(label: shareHint),
          SizedBox(height: 24.w),
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
          //     mainAxisAlignment: MainAxisAlignment.spaceAround,
          //     children: [
          //       _ShareTarget(
          //         color: const Color(0xFF1877F2),
          //         imageUrl: "share_facebook",
          //         label: context.l10n.playerFacebook,
          //         onTap: onFacebookTap,
          //         iconColor: Colors.white,
          //       ),
          //       _ShareTarget(
          //         color: const Color(0xFF6B6570),
          //         imageUrl: "share_copy",
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

class PlayerShareLoadingSheet extends StatelessWidget {
  const PlayerShareLoadingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: 249,
      child: Center(
        child: SizedBox.square(
          dimension: 24.w,
          child: CircularProgressIndicator(strokeWidth: 2.w),
        ),
      ),
    );
  }
}

/// 赠送会员/短剧使用的分享弹框。分享目标与播放页保持一致，并额外支持资格提示态。
class GiftShareSheet extends StatelessWidget {
  const GiftShareSheet({
    required this.quotaLabel,
    required this.isEligible,
    required this.onFacebookTap,
    required this.onCopyLinkTap,
    this.unavailableDescription,
    super.key,
  });

  final String quotaLabel;
  final bool isEligible;
  final VoidCallback onFacebookTap;
  final VoidCallback onCopyLinkTap;
  final String? unavailableDescription;

  @override
  Widget build(BuildContext context) {
    return _CompactPlayerSheet(
      height: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 40.w, height: 40.w),
              Text(
                context.l10n.shareTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight(510),
                ),
              ),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          if (isEligible) ...[
            SizedBox(height: 16.w),
            _GiftQuotaBanner(label: quotaLabel),
            SizedBox(height: 24.w),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareTarget(
                  color: const Color(0xFF1877F2),
                  imageUrl: "share_facebook",
                  label: context.l10n.playerFacebook,
                  onTap: onFacebookTap,
                ),
                _ShareTarget(
                  color: const Color(0xFFAAA8BD),
                  imageUrl: "share_copy",
                  label: context.l10n.shareActionCopyLink,
                  onTap: onCopyLinkTap,
                  iconColor: const Color(0xFF1A171E),
                ),
              ],
            ),
          ] else ...[
            SizedBox(height: 18.w),
            Image.asset(
              'assets/images/membership/share_gift.png',
              width: 82.w,
              height: 82.w,
              filterQuality: FilterQuality.low,
            ),
            SizedBox(height: 14.w),
            Text(
              context.l10n.giftShareUnavailableTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6.w),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                unavailableDescription ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.48),
                  height: 1.35,
                ),
              ),
            ),
          ],
          SizedBox(height: 45.w),
        ],
      ),
    );
  }
}

class PlayerGiftShareSheet extends StatefulWidget {
  const PlayerGiftShareSheet({
    required this.quotaLabel,
    required this.shareHint,
    required this.isGiftAvailable,
    required this.unavailableDescription,
    required this.onShareFacebookTap,
    required this.onShareCopyLinkTap,
    required this.onGiftFacebookTap,
    required this.onGiftCopyLinkTap,
    super.key,
  });

  final String quotaLabel;
  final String shareHint;
  final bool isGiftAvailable;
  final String unavailableDescription;
  final VoidCallback onShareFacebookTap;
  final VoidCallback onShareCopyLinkTap;
  final VoidCallback onGiftFacebookTap;
  final VoidCallback onGiftCopyLinkTap;

  @override
  State<PlayerGiftShareSheet> createState() => _PlayerGiftShareSheetState();
}

class _PlayerGiftShareSheetState extends State<PlayerGiftShareSheet> {
  var _giftSelected = false;

  @override
  Widget build(BuildContext context) {
    final giftSelected = _giftSelected;
    return _CompactPlayerSheet(
      // Keep both tabs at the taller gift-unavailable height so switching tabs
      // does not move the sheet.
      height: 270,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 40.w, height: 40.w),
              Expanded(
                child: Container(
                  height: 36.w,
                  padding: EdgeInsets.all(4.w),
                  margin: EdgeInsets.symmetric(horizontal: 10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF313136),
                    borderRadius: BorderRadius.circular(40.w),
                  ),
                  child: Row(
                    children: [
                      _PlayerShareTab(
                        label: context.l10n.shareTitle,
                        selected: !giftSelected,
                        onTap: () => setState(() => _giftSelected = false),
                      ),
                      _PlayerShareTab(
                        label: context.l10n.dramaGiftTabGift,
                        selected: giftSelected,
                        onTap: () => setState(() => _giftSelected = true),
                      ),
                    ],
                  ),
                ),
              ),
              _CloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          if (!giftSelected) ...[
            SizedBox(height: 16.w),
            _ShareHintBanner(label: widget.shareHint),
            SizedBox(height: 24.w),
            _GiftShareTargets(
              onFacebookTap: widget.onShareFacebookTap,
              onCopyLinkTap: widget.onShareCopyLinkTap,
            ),
          ] else if (widget.isGiftAvailable) ...[
            SizedBox(height: 16.w),
            _GiftQuotaBanner(label: widget.quotaLabel),
            SizedBox(height: 24.w),
            _GiftShareTargets(
              onFacebookTap: widget.onGiftFacebookTap,
              onCopyLinkTap: widget.onGiftCopyLinkTap,
            ),
          ] else ...[
            SizedBox(height: 18.w),
            Image.asset(
              'assets/images/membership/share_gift.png',
              width: 82.w,
              height: 82.w,
            ),
            SizedBox(height: 14.w),
            Text(
              context.l10n.giftShareUnavailableTitle,
              style: TextStyle(color: Colors.white, fontSize: 15.sp),
            ),
            SizedBox(height: 6.w),
            Text(
              widget.unavailableDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 12.sp,
              ),
            ),
          ],
          // const SizedBox(height: 69),
        ],
      ),
    );
  }
}

class _PlayerShareTab extends StatelessWidget {
  const _PlayerShareTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF696971) : Colors.transparent,
          borderRadius: BorderRadius.circular(40.w),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            height: 14 / 18,
            fontWeight: FontWeight(selected ? 510 : 400),
          ),
        ),
      ),
    ),
  );
}

class _GiftShareTargets extends StatelessWidget {
  const _GiftShareTargets({
    required this.onFacebookTap,
    required this.onCopyLinkTap,
  });

  final VoidCallback onFacebookTap;
  final VoidCallback onCopyLinkTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _ShareTarget(
        color: const Color(0xFF1877F2),
        imageUrl: 'share_facebook',
        label: context.l10n.playerFacebook,
        onTap: onFacebookTap,
      ),
      _ShareTarget(
        color: const Color(0xFFAAA8BD),
        imageUrl: 'share_copy',
        label: context.l10n.shareActionCopyLink,
        onTap: onCopyLinkTap,
      ),
    ],
  );
}

class _GiftQuotaBanner extends StatelessWidget {
  const _GiftQuotaBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(24.w),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/player/share_member_icon.png',
            width: 16.w,
            height: 20.w,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareHintBanner extends StatelessWidget {
  const _ShareHintBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('player_share_hint'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(24.w),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/profile/coin.png',
            width: 20.w,
            height: 20.w,
            filterQuality: FilterQuality.low,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
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
          SizedBox(height: 2.w),
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
                        width: 16.w,
                        height: 16.w,
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
                  fontSize: 14.sp,
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
                        width: 16.w,
                        height: 16.w,
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
                  fontSize: 14.sp,
                  height: 16 / 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          SizedBox(height: 28.w),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: AppPrimaryButton(
              key: const ValueKey('player_coin_unlock_confirm'),
              label: context.l10n.playerPlay,
              icon: Icons.play_arrow_rounded,
              onPressed: _isSubmitting ? null : () => unawaited(_submit()),
            ),
          ),
          SizedBox(height: 24.w),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          SizedBox(height: 20.w),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.autoUnlockNext,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12.sp,
                  height: 16 / 12,
                ),
              ),
              SizedBox(width: 27.w),
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

  static const rates = [3.0, 2.0, 1.5, 1.25, 1.0, 0.75];

  final double selectedRate;
  final ValueChanged<double> onRateSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1C1C),
      borderRadius: BorderRadius.vertical(top: Radius.circular(32.w)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(width: 40.w),
                  Expanded(
                    child: Text(
                      context.l10n.playerSpeed,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              SizedBox(height: 12.w),
              for (final rate in rates)
                Semantics(
                  selected: selectedRate == rate,
                  button: true,
                  child: InkWell(
                    key: ValueKey('player_speed_option_$rate'),
                    borderRadius: BorderRadius.circular(24.w),
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onTap: () {
                      onRateSelected(rate);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 56.w,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: selectedRate == rate
                            ? const Color(0xFF2C2C2E)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24.w),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${rate}x',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: selectedRate == rate
                                  ? Colors.white.withValues(alpha: .9)
                                  : Colors.white.withValues(alpha: .4),
                            ),
                          ),
                          const Spacer(),
                          if (selectedRate == rate)
                            Icon(
                              Icons.check_rounded,
                              key: ValueKey('player_speed_selected_check'),
                              color: Colors.white,
                              size: 20.w,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
                width: 275.w,
                height: 44.w,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.45,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.w),
                    ),
                    textStyle: TextStyle(
                      fontSize: 14.sp,
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
  const _CompactPlayerSheet({
    this.height,
    this.scaleHeight = true,
    required this.child,
  });

  final double? height;
  final bool scaleHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        key: const ValueKey('player_compact_sheet_surface'),
        color: const Color(0xFF202123),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
        clipBehavior: Clip.antiAlias,
        child: height == null
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 18.w),
                  child: child,
                ),
              )
            : SizedBox(
                height: scaleHeight ? height!.w : height,
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 18.w),
                  child: child,
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
      child: Column(
        children: [
          Image.asset(
            "assets/images/player/$imageUrl.png",
            width: 56.w,
            height: 56.w,
          ),
          SizedBox(height: 6.w),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight(510),
              height: 16 / 12,
            ),
          ),
        ],
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
        dimension: 40.w,
        child: SvgPicture.asset(
          "assets/images/player/close.svg",
          width: 40.w,
          height: 40.w,
        ),
      ),
    );
  }
}
