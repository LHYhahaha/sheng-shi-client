import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../domain/store_package.dart';

class StoreCoinPackageCard extends StatelessWidget {
  const StoreCoinPackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
    this.width = 160,
    super.key,
  });

  final StorePackage package;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: width,
          height: 85.w,
          decoration: BoxDecoration(
            color: const Color(0x80414143),
            borderRadius: BorderRadius.circular(AppRadii.sm.w),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.w, 16.w, 12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/profile/coin.png',
                          width: 20.w,
                          height: 20.w,
                        ),
                        SizedBox(width: AppSpacing.xs.w),
                        Flexible(
                          child: Text(
                            package.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                  fontSize: 18.sp,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (package.bonusLabel != null) ...[
                      SizedBox(height: AppSpacing.xs.w),
                      Text(
                        package.bonusLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.5),
                          height: 1.3,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        package.priceLabel,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (package.badgeLabel != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    height: 19.w,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm.w,
                      vertical: 2.w,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF9E53),
                          Color(0xFFFE1340),
                          Color(0xFFFE3273),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(AppRadii.sm.w),
                        bottomLeft: Radius.circular(AppRadii.sm.w),
                      ),
                    ),
                    child: Text(
                      package.badgeLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.sp,
                        height: 1.5,
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
