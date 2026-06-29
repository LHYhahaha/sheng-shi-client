import 'package:flutter/material.dart';

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
          height: 85,
          decoration: BoxDecoration(
            color: const Color(0x80414143),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/profile/coin.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: AppSpacing.xs),
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
                                  fontSize: 18,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (package.bonusLabel != null) ...[
                      const SizedBox(height: AppSpacing.xs),
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
                    height: 19,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF9E53),
                          Color(0xFFFE1340),
                          Color(0xFFFE3273),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(AppRadii.sm),
                        bottomLeft: Radius.circular(AppRadii.sm),
                      ),
                    ),
                    child: Text(
                      package.badgeLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
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
