import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badgeLabel,
    this.iconAssetPath = 'assets/images/profile/language_icon_figma.png',
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? badgeLabel;
  final VoidCallback onTap;
  final String iconAssetPath;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.w),
        // subtitle != null ? 52 : 40,
        child: Row(
          crossAxisAlignment: subtitle != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: subtitle != null
                  ? EdgeInsets.only(top: 8.w)
                  : EdgeInsets.zero,
              child: Image.asset(
                iconAssetPath,
                width: 24.w,
                height: 24.w,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight(400),
                      fontSize: 14.sp,
                      height: 1.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.w),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 12.sp,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badgeLabel != null) ...[
              Container(
                key: const Key('profile_menu_reward_badge'),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF007A),
                  borderRadius: BorderRadius.circular(12.w),
                ),
                child: Text(
                  badgeLabel!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
            ],
            Padding(
              padding: subtitle != null
                  ? EdgeInsets.only(top: 8.w)
                  : EdgeInsets.zero,
              child: Image.asset(
                "assets/images/common/grey_right_icon.png",
                color: Colors.white.withValues(alpha: 0.4),
                height: 20.w,
                width: 20.w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
