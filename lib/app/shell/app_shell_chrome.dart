import 'package:flutter_riverpod/flutter_riverpod.dart';

final appShellBottomNavigationVisibleProvider =
    NotifierProvider<AppShellBottomNavigationVisible, bool>(
      AppShellBottomNavigationVisible.new,
    );

/// Shell 底部导航显隐状态。
///
/// 单剧播放器、My List 批量编辑等全屏/底部操作场景会临时隐藏导航。调用方必须在
/// dispose 或退出态恢复 show，避免全局 shell chrome 被某个页面状态永久占用。
class AppShellBottomNavigationVisible extends Notifier<bool> {
  @override
  bool build() => true;

  void show() {
    state = true;
  }

  void hide() {
    state = false;
  }
}
