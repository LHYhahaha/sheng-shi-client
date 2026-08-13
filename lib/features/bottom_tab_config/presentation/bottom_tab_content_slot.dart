import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/webview_page.dart';
import '../application/bottom_tab_config_controller.dart';

/// 保持 StatefulShell 原分支位置，将命中的 Tab 内容替换为内嵌 H5。
class BottomTabContentSlot extends ConsumerWidget {
  const BottomTabContentSlot({
    required this.slot,
    required this.defaultTitle,
    required this.child,
    super.key,
  });

  final String slot;
  final String defaultTitle;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bottomTabConfigControllerProvider);
    final tab = ref
        .read(bottomTabConfigControllerProvider.notifier)
        .tabForSlot(slot);
    if (tab == null) {
      return child;
    }
    final title = context.l10n.resolveDynamicTabText(
      tab.nameI18nKey,
      fallback: defaultTitle,
    );
    return WebViewPage(
      key: ValueKey('dynamic_bottom_tab_${tab.tabConfigId}'),
      url: tab.h5Url,
      title: title,
      showAppBar: false,
    );
  }
}
