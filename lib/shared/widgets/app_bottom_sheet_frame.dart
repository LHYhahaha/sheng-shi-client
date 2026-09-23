import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 通用底部弹层内容框架。
///
/// 统一 handle、padding 和标题位置，业务弹层只填内容，避免每个弹层自己处理安全区。
class AppBottomSheetFrame extends StatelessWidget {
  const AppBottomSheetFrame({
    required this.title,
    required this.children,
    super.key,
  });

  /// 弹层标题。
  final String title;

  /// 弹层内容。
  ///
  /// 由调用方传入，框架不负责滚动；长内容需要调用方自行包滚动容器。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('app_bottom_sheet_frame_surface'),
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.w)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w,
            AppSpacing.md.w,
            AppSpacing.lg.w,
            AppSpacing.lg.w,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.w,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999.w),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg.w),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: AppSpacing.lg.w),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
