import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

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
        title: Text(title),
        actions: [
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: trailing,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: children,
      ),
    );
  }
}
