import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import 'app_cached_network_image.dart';

/// 三列紧凑海报网格，供推荐、搜索等剧集列表复用。
class AppCompactDramaGrid extends StatelessWidget {
  const AppCompactDramaGrid({
    required this.itemCount,
    required this.hasTagRow,
    required this.itemBuilder,
    super.key,
  });

  static const crossAxisCount = 3;
  static const spacing = 8.0;

  final int itemCount;
  final bool hasTagRow;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledSpacing = spacing.w;
        final tileWidth =
            (constraints.maxWidth - scaledSpacing * (crossAxisCount - 1)) /
            crossAxisCount;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: scaledSpacing,
            mainAxisSpacing: scaledSpacing,
            mainAxisExtent:
                tileWidth / AppCompactDramaCard.coverAspectRatio +
                (hasTagRow
                    ? AppCompactDramaCard.textHeightWithTag.w
                    : AppCompactDramaCard.textHeightWithoutTag.w),
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

/// 紧凑网格中的单张剧集卡。角标由调用方按场景传入。
class AppCompactDramaCard extends StatelessWidget {
  const AppCompactDramaCard({
    required this.coverUrl,
    required this.title,
    required this.tags,
    required this.onTap,
    this.topLeftOverlay,
    super.key,
  });

  static const coverAspectRatio = 109 / 147;
  static const textHeightWithoutTag = 48.0;
  // 字体在设备像素取整时可能多占 1px，避免两行标题加标签溢出。
  static const textHeightWithTag = 73.0;

  final String coverUrl;
  final String title;
  final List<String> tags;
  final VoidCallback onTap;
  final Widget? topLeftOverlay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: coverAspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppCachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover),
                  if (topLeftOverlay != null)
                    Align(alignment: Alignment.topLeft, child: topLeftOverlay),
                ],
              ),
            ),
          ),
          SizedBox(
            height: tags.isNotEmpty
                ? textHeightWithTag.w
                : textHeightWithoutTag.w,
            child: Padding(
              padding: EdgeInsets.only(top: 4.w, bottom: 8.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textScaler: TextScaler.noScaling,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      // height: 16 / 12,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    SizedBox(height: 6.w),
                    Text(
                      tags.first,
                      textScaler: TextScaler.noScaling,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.5),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        // height: 16 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
