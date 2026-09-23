import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_spacing.dart';
import 'app_secondary_page_header.dart';

/// 通用简单页面骨架。
///
/// 适合静态列表页或设置页。复杂全屏体验不要强套这个组件，避免 app bar/list padding
/// 和业务设计冲突。
class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  /// 页面标题。
  final String title;

  /// AppBar 右侧操作。
  final Widget? trailing;

  /// 页面列表内容。
  ///
  /// 组件内部使用 ListView，传入项不应再依赖外层滚动。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSecondaryPageHeader.height.w,
        leadingWidth:
            (AppSecondaryPageHeader.backButtonSize +
                    AppSecondaryPageHeader.horizontalInset * 2)
                .w,
        leading: Padding(
          padding: EdgeInsets.only(
            left: AppSecondaryPageHeader.horizontalInset.w,
          ),
          child: AppSecondaryPageBackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        centerTitle: true,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        actions: [
          if (trailing != null)
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.lg.w),
              child: trailing,
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.lg.w),
        children: children,
      ),
    );
  }
}
