import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_feed_controller.dart';
import 'player_overlay_orchestrator.dart';
import 'player_playback_controller.dart';
import 'player_recharge_unlock_controller.dart';
import 'player_session_registry.dart';
import 'player_ui_controller.dart';

/// 暂停并释放所有已注册播放器 session，取消 overlay/preload/pending unlock 上下文。
Future<void> runPlayerSessionCleanup(Ref ref) async {
  await runPlayerSessionCleanupWith(
    read: <T>(dynamic provider) => ref.read(provider),
    invalidate: (dynamic provider) => ref.invalidate(provider),
  );
}

/// 供测试或 [ProviderContainer] 直接调用。
Future<void> runPlayerSessionCleanupWith({
  required T Function<T>(dynamic provider) read,
  required void Function(dynamic provider) invalidate,
}) async {
  final keys = <String>{
    PlayerPlaybackSessionKeys.forYouTab,
    ...read(playerSessionRegistryProvider),
  };

  for (final sessionKey in keys) {
    await _cleanupPlayerSession(
      read: read,
      invalidate: invalidate,
      sessionKey: sessionKey,
    );
  }

  try {
    read(playerSessionRegistryProvider.notifier).clear();
  } catch (_) {}
}

Future<void> _cleanupPlayerSession({
  required T Function<T>(dynamic provider) read,
  required void Function(dynamic provider) invalidate,
  required String sessionKey,
}) async {
  try {
    read(
      playerOverlayOrchestratorProvider(sessionKey).notifier,
    ).cancelPending();
  } catch (_) {}

  try {
    read(
      playerRechargeUnlockControllerProvider(sessionKey).notifier,
    ).resetForSessionCleanup();
  } catch (_) {}

  try {
    read(
      playerUiControllerProvider(sessionKey).notifier,
    ).resetForSessionCleanup();
  } catch (_) {}

  try {
    final playback = read(
      playerPlaybackControllerProvider(sessionKey).notifier,
    );
    await playback.detachSurfaceForVisibility(syncState: false);
    await playback.disposeSession(syncState: false);
  } catch (_) {}

  try {
    invalidate(playerFeedControllerProvider(sessionKey));
  } catch (_) {}
}
