import 'package:flutter/material.dart';

/// 从 root navigator 展示 bottom sheet（调用方须传入 root [BuildContext]）。
Future<T?> showAppModalRootBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = false,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.7),
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    builder: builder,
  );
}
