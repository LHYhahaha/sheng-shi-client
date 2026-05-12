import 'package:flutter_riverpod/flutter_riverpod.dart';

final appShellBottomNavigationVisibleProvider =
    NotifierProvider<AppShellBottomNavigationVisible, bool>(
      AppShellBottomNavigationVisible.new,
    );

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
