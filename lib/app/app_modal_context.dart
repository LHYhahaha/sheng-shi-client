import 'package:flutter/material.dart';

import 'app_root_navigator_key.dart';

/// 解析用于全局 modal 展示的 root overlay context。
BuildContext resolveAppModalPresentationContext(BuildContext fallback) {
  final navigator = appRootNavigatorKey.currentState;
  final overlayContext = navigator?.overlay?.context;
  if (overlayContext != null && overlayContext.mounted) {
    return overlayContext;
  }
  final navContext = appRootNavigatorKey.currentContext;
  if (navContext != null && navContext.mounted) {
    return navContext;
  }
  return fallback;
}
