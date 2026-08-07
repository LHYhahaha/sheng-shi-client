import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../auth/domain/auth_session.dart';
import '../../application/profile_controller.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.state,
    this.onLoginTap,
    this.onAccountTap,
    this.onGuestTap,
    this.secondaryText,
    this.displayName,
    super.key,
  });

  final ProfileState state;
  final VoidCallback? onLoginTap;
  final VoidCallback? onAccountTap;
  final VoidCallback? onGuestTap;

  /// 传入时替换默认的 Show ID 展示，不提供复制操作。
  final String? secondaryText;

  /// 传入时替换默认的昵称/登录文案。
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolvedDisplayName =
        displayName ??
        (state.isLoggedIn ? (state.nickname ?? '--') : l10n.profileLogin);

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    resolvedDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  GestureDetector(
                    onTap: secondaryText == null
                        ? () {
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
                          }
                        : null,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            secondaryText ?? 'ID:${state.showId ?? '--'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  height: 1.3,
                                ),
                          ),
                        ),
                        if (secondaryText == null) ...[
                          const SizedBox(width: 4),
                          SvgPicture.asset(
                            'assets/images/profile/copy.svg',
                            colorFilter: ColorFilter.mode(
                              AppColors.textPrimary.withValues(alpha: 0.8),
                              BlendMode.srcIn,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
        return AppCachedNetworkImage(
          imageUrl: avatarResource.value,
          fit: BoxFit.cover,
          errorWidget: Image.asset(
            authDefaultAvatarAssetPath,
            fit: BoxFit.cover,
          ),
        );
      } else if (avatarResource.isAsset) {
        return Image.asset(avatarResource.value, fit: BoxFit.cover);
      }
    }
    return Image.asset(state.avatarAssetPath, fit: BoxFit.cover);
  }
}
