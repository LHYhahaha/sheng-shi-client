import 'package:flutter/material.dart';

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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}
