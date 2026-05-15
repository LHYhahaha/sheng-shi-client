import 'package:flutter/material.dart';

/// 应用主按钮。
///
/// 用于主要行动按钮，保持 FilledButton 行为一致。禁用态通过 `onPressed == null` 表达。
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调。
  ///
  /// null 表示禁用，调用方不要额外包 GestureDetector 绕过禁用态。
  final VoidCallback? onPressed;

  /// 可选前置图标。
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: child),
    );
  }
}
