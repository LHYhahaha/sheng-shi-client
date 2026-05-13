import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/profile_controller.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.state, super.key});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName = state.isLoggedIn
        ? state.nickname ?? state.userId
        : l10n.profileLogin;

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(state.avatarAssetPath, fit: BoxFit.cover),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ID:${state.userId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_rounded,
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                    size: 12,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
