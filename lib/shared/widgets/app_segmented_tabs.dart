import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// 通用分段 tab。
///
/// 只适合少量文本 tab。复杂筛选、带图标或可滚动分类应使用业务组件，避免交互语义混乱。
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  /// tab 文案列表。
  final List<String> tabs;

  /// 当前选中索引。
  final int selectedIndex;

  /// tab 切换回调。
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.sm.w),
      ),
      padding: EdgeInsets.all(3.w),
      child: Row(
        children: [
          for (final entry in tabs.indexed)
            Expanded(
              child: _Segment(
                label: entry.$2,
                selected: entry.$1 == selectedIndex,
                onTap: () => onChanged(entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surfaceMuted : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.sm.w),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm.w),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.w),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
