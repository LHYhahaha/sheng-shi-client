import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    required this.title,
    required this.onTap,
    this.iconAssetPath = 'assets/images/profile/language_icon_figma.png',
    this.enabled = true,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final String iconAssetPath;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Image.asset(
              iconAssetPath,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textPrimary.withValues(alpha: 0.55),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
