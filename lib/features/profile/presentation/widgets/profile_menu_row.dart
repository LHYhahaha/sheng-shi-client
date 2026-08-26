import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconAssetPath = 'assets/images/profile/language_icon_figma.png',
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
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
        padding: EdgeInsets.symmetric(vertical: 14),
        // subtitle != null ? 52 : 40,
        child: Row(
          crossAxisAlignment: subtitle != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: subtitle != null
                  ? const EdgeInsets.only(top: 8.0)
                  : EdgeInsets.zero,
              child: Image.asset(
                iconAssetPath,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Color(0XFFB5B2B8),
                      fontWeight: FontWeight(400),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: subtitle != null
                  ? const EdgeInsets.only(top: 8.0)
                  : EdgeInsets.zero,
              child: Image.asset(
                "assets/images/common/white_right.png",
                height: 20,
                width: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
