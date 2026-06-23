import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/domain/auth_session.dart';
import '../../application/profile_controller.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.state,
    this.onLoginTap,
    this.onAccountTap,
    this.onGuestTap,
    super.key,
  });

  final ProfileState state;
  final VoidCallback? onLoginTap;
  final VoidCallback? onAccountTap;
  final VoidCallback? onGuestTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName = state.isLoggedIn
        ? (state.nickname ?? '--')
        : l10n.profileLogin;

    void handleTap() {
      if (onGuestTap != null) {
        onGuestTap!();
      } else if (state.isLoggedIn) {
        onAccountTap?.call();
      } else {
        onLoginTap?.call();
      }
    }

    return InkWell(
      onTap: handleTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: _buildAvatarImage(),
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
                      'ID:${state.showId ?? '--'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final showId = state.showId;
                        if (showId != null) {
                          Clipboard.setData(ClipboardData(text: showId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.profileCopySuccess),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Icon(
                        Icons.copy_rounded,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                        size: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage() {
    final avatarResource = state.avatarResource;
    if (avatarResource != null) {
      if (avatarResource.isNetwork) {
        return Image.network(
          avatarResource.value.trim(),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Image.asset(authDefaultAvatarAssetPath, fit: BoxFit.cover);
          },
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(authDefaultAvatarAssetPath, fit: BoxFit.cover);
          },
        );
      } else if (avatarResource.isAsset) {
        return Image.asset(avatarResource.value, fit: BoxFit.cover);
      }
    }
    return Image.asset(state.avatarAssetPath, fit: BoxFit.cover);
  }
}
