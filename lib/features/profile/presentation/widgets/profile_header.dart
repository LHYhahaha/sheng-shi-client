import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/toast/app_center_toast.dart';
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
    this.loginRewardCoins,
    this.isMemberPage,
    super.key,
  });

  final ProfileState state;
  final VoidCallback? onLoginTap;
  final VoidCallback? onAccountTap;
  final VoidCallback? onGuestTap;
  final bool? isMemberPage;

  /// 传入时替换默认的 Show ID 展示，不提供复制操作。
  final String? secondaryText;

  /// 传入时替换默认的昵称/登录文案。
  final String? displayName;

  /// 未绑定三方账号时展示的登录奖励；由页面传入，方便后续接入接口。
  final int? loginRewardCoins;

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
        height: 52.w,
        child: Row(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: _buildAvatarImage(),
            ),
            SizedBox(width: 13.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        children: [
                          Text(
                            resolvedDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                          ),
                          SizedBox(width: 4.w),
                          state.isLoggedIn || isMemberPage == true
                              ? SizedBox()
                              : Image.asset(
                                  "assets/images/profile/log_icon.png",
                                  height: 20.w,
                                  width: 20.w,
                                ),
                        ],
                      ),
                      if (!state.isLoggedIn && (loginRewardCoins ?? 0) > 0)
                        Positioned(
                          top: -20.w,
                          left: 13.w,
                          child: Stack(
                            key: const Key('profile_login_reward_badge'),
                            children: [
                              Positioned.fill(
                                child: SvgPicture.asset(
                                  'assets/images/profile/login_reward_badge_bg.svg',
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Container(
                                constraints: BoxConstraints(minWidth: 54.w),
                                padding: EdgeInsets.fromLTRB(
                                  6.w,
                                  2.w,
                                  6.w,
                                  4.w,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/profile/coin.png',
                                      width: 13.w,
                                      height: 13.w,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      '+$loginRewardCoins',
                                      style:  TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 1.w),
                  GestureDetector(
                    onTap: secondaryText == null
                        ? () {
                            final showId = state.showId;
                            if (showId != null) {
                              Clipboard.setData(ClipboardData(text: showId));
                              showAppCenterToast(l10n.profileCopySuccess);
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
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
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
