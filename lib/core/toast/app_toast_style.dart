import 'package:flutter/material.dart';

/// 全局 toast 视觉与时长约定。
class AppToastStyle {
  const AppToastStyle._();

  static const Duration displayDuration = Duration(milliseconds: 1800);

  static const Color backgroundColor = Color(0xCC1D1D20);

  static const Color successIconColor = Color(0xFF4CD964);
  static const Color errorIconColor = Color(0xFFFF453A);
  static const Color infoIconColor = Color(0xFF64D2FF);
  static const Color warningIconColor = Color(0xFFFFD60A);

  static const TextStyle messageStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );

  static EdgeInsets marginFor(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 12;
    return EdgeInsets.fromLTRB(16, top, 16, 0);
  }
}
