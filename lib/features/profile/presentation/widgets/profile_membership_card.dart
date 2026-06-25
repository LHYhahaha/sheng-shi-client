import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../application/profile_controller.dart';

class ProfileMembershipCard extends StatelessWidget {
  const ProfileMembershipCard({
    required this.membership,
    required this.onTap,
    super.key,
  });

  final ProfileMembershipState membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final isActive = membership.isActive;
    final title = isActive
        ? l10n.profileVipCardMembership
        : l10n.profileVipCardMembershipJoin;
    final subtitle = isActive
        ? '${l10n.profileMembershipValidUntil} ${_formatExpiry(membership.expiresAt)}'
        : l10n.profileBenefitsIntro;

    return Container(
      padding: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xff220B04),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        children: [
          GestureDetector(
            key: const ValueKey('profile_membership_entry'),
            behavior: HitTestBehavior.opaque,
            onTap: membership.entryEnabled && !isActive ? onTap : null,
            child: Container(
              margin: EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.fill,
                  image: AssetImage("assets/images/profile/membership_bac.png"),
                ),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              color: const Color(0xFFFFF0CD),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: const Color(
                                0xFFFFE0A2,
                              ).withValues(alpha: 0.6),
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  isActive
                      ? SizedBox()
                      : _JoinButton(
                          enabled: !isActive,
                          label: l10n.profileJoin,
                        ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _BenefitItem(
                iconAssetPath: 'assets/images/profile/icon_series.svg',
                label: l10n.profileSeriesBenefit,
              ),
              _BenefitItem(
                iconAssetPath: 'assets/images/profile/icon_points.svg',
                label: l10n.profileDailyPoints,
              ),
              _BenefitItem(
                iconAssetPath: 'assets/images/profile/icon_download.svg',
                label: l10n.profileDownload,
              ),
              _BenefitItem(
                iconAssetPath: 'assets/images/profile/icon_hd.svg',
                label: l10n.profileFullHd,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatExpiry(DateTime? value) {
    if (value == null) {
      return '--/--/--';
    }
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = (local.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.enabled, required this.label});

  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Container(
        width: 91,
        height: 32,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0D0),
          borderRadius: BorderRadius.circular(AppRadii.xs),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: enabled ? const Color(0xFF2B160A) : AppColors.black,
            fontSize: 14,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.iconAssetPath, required this.label});

  final String iconAssetPath;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconAssetPath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFFFFEBC3).withValues(alpha: 0.65),
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
