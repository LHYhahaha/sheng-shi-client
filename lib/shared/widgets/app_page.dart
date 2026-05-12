import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;
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
