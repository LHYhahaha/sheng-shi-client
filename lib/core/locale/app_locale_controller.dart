import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLocaleControllerProvider =
    NotifierProvider<AppLocaleController, Locale>(AppLocaleController.new);

/// 应用语言控制器。
///
/// 当前只在内存中切换固定语言包，用于 MVP 验证。接持久化时应在这里统一读写，
/// 不要让页面直接保存 Locale，避免启动语言、系统语言和用户选择互相覆盖。
class AppLocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');

  void select(Locale locale) {
    state = locale;
  }
}
