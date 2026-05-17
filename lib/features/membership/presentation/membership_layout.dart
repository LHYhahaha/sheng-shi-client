import 'package:flutter/material.dart';

/// Figma 订阅页（375×962）布局常量，用于 Membership 页面对齐。
abstract final class MembershipLayout {
  static const background = Color(0xFF0F0F10);

  /// Hero 图区域高度（含渐隐到底色）。
  static const heroBackgroundHeight = 211.0;

  /// 自屏幕顶部的绝对 Y（Figma artboard 坐标）。
  static const heroTitleTop = 127.0;
  static const heroSubtitleTop = 168.0;
  static const planCardsTop = 213.0;

  /// 可滚动区域顶部（与套餐卡 Figma Y 对齐）；其上 hero/标题不被滚动内容覆盖。
  static const scrollContentTop = planCardsTop;

  static const planDescriptionTop = 390.0;
  static const benefitsPanelTop = 411.0;

  static const horizontalPadding = 16.0;
  static const planCardWidth = 109.0;
  static const planCardHeight = 156.0;
  static const planCardGap = 8.0;
  static const planCardRadius = 12.0;

  /// 三张套餐卡 + 间距总宽（375 屏下左右各 16 边距）。
  static const planCardGroupWidth = planCardWidth * 3 + planCardGap * 2;

  static const navButtonSize = 44.0;
  static const navButtonLeft = 16.0;

  static const benefitsTitlePaddingTop = 24.0;
  static const benefitsTitleLineWidth = 52.0;
  static const benefitsRowGap = 20.0;
  static const benefitsIconSize = 30.0;
  static const benefitsIconRadius = 10.0;
}
