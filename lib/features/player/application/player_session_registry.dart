import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 跟踪当前存活的播放器 session key，供 session cleanup 遍历释放。
final playerSessionRegistryProvider =
    NotifierProvider<PlayerSessionRegistry, Set<String>>(
      PlayerSessionRegistry.new,
    );

class PlayerSessionRegistry extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void register(String sessionKey) {
    if (sessionKey.isEmpty || state.contains(sessionKey)) {
      return;
    }
    state = {...state, sessionKey};
  }

  void unregister(String sessionKey) {
    if (!state.contains(sessionKey)) {
      return;
    }
    final next = Set<String>.from(state)..remove(sessionKey);
    state = next;
  }

  void clear() {
    state = const {};
  }
}
