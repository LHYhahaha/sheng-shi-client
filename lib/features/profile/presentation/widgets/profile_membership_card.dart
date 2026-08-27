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
      padding: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD69B), Color(0xFFFFF0DC)],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xffffffff).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          children: [
            GestureDetector(
              key: const ValueKey('profile_membership_entry'),
              behavior: HitTestBehavior.opaque,
              onTap: membership.entryEnabled ? onTap : null,
              child: Container(
                margin: EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    // fit: BoxFit.fill,
                    alignment: Alignment.centerRight,
                    image: AssetImage("assets/images/profile/vip_v_brown.png"),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFD69B), Color(0xFFFFF0DC)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadii.sm),
                    topRight: Radius.circular(AppRadii.sm),
                  ),
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
                                color: const Color(0xFF421C07),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                            // const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: const Color(
                                  0xFF421C07,
                                ).withValues(alpha: 0.5),
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight(400),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _JoinButton(
                      enabled: membership.entryEnabled,
                      label: isActive ? l10n.profileMember : l10n.profileJoin,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _BenefitItem(
                  iconAssetPath: 'assets/images/profile/brown_series.svg',
                  label: l10n.profileSeriesBenefit,
                ),
                _BenefitItem(
                  iconAssetPath: 'assets/images/profile/brown_points.svg',
                  label: l10n.profileDailyPoints,
                ),
                _BenefitItem(
                  iconAssetPath: 'assets/images/profile/brown_download.svg',
                  label: l10n.profileDownload,
                ),
                _BenefitItem(
                  iconAssetPath: 'assets/images/profile/brown_hd.svg',
                  label: l10n.profileFullHd,
                ),
              ],
            ),
          ],
        ),
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
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF421C07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: enabled ? const Color(0xFFFEF4E4) : AppColors.black,
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
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF743A13),
              fontWeight: FontWeight(400),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
