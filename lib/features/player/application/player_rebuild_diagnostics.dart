import 'package:flutter/foundation.dart';

abstract final class PlayerRebuildDiagnostics {
  static const enabled =
      bool.fromEnvironment('PLAYER_REBUILD_LOGS') ||
      bool.fromEnvironment('PLAYER_TIMING_LOGS');

  static int _playerPageBuilds = 0;
  static int _pageViewItemBuilds = 0;
  static int _currentChromeBuilds = 0;
  static int _nonCurrentChromeBuilds = 0;
  static int _videoMounts = 0;
  static int _videoUnmounts = 0;
  static int _videoControllerReplacements = 0;

  static void recordPlayerPageBuild({
    required String sessionKey,
    required String? itemId,
  }) {
    if (!enabled) {
      return;
    }
    _playerPageBuilds += 1;
    _log(
      'PlayerPage.build',
      'count=$_playerPageBuilds session=$sessionKey item=${itemId ?? 'null'}',
    );
  }

  static void recordPageViewItemBuild({
    required String itemId,
    required bool isCurrent,
  }) {
    if (!enabled) {
      return;
    }
    _pageViewItemBuilds += 1;
    if (isCurrent) {
      _currentChromeBuilds += 1;
    } else {
      _nonCurrentChromeBuilds += 1;
    }
    _log(
      'PageView.itemBuilder',
      [
        'count=$_pageViewItemBuilds',
        'item=$itemId',
        'current=$isCurrent',
        'currentChrome=$_currentChromeBuilds',
        'nonCurrentChrome=$_nonCurrentChromeBuilds',
      ].join(' '),
    );
  }

  static void recordVideoMounted({
    required String itemId,
    required Object? controller,
  }) {
    if (!enabled) {
      return;
    }
    _videoMounts += 1;
    _log(
      'Video.mount',
      'count=$_videoMounts item=$itemId controller=${identityHashCode(controller)}',
    );
  }

  static void recordVideoUnmounted({
    required String itemId,
    required Object? controller,
  }) {
    if (!enabled) {
      return;
    }
    _videoUnmounts += 1;
    _log(
      'Video.unmount',
      'count=$_videoUnmounts item=$itemId controller=${identityHashCode(controller)}',
    );
  }

  static void recordVideoControllerReplaced({
    required String itemId,
    required Object? previous,
    required Object? next,
  }) {
    if (!enabled) {
      return;
    }
    _videoControllerReplacements += 1;
    _log(
      'Video.controller.replace',
      [
        'count=$_videoControllerReplacements',
        'item=$itemId',
        'previous=${identityHashCode(previous)}',
        'next=${identityHashCode(next)}',
      ].join(' '),
    );
  }

  static void recordTiming(
    String event, {
    String? itemId,
    Duration? elapsed,
    String? details,
  }) {
    if (!enabled) {
      return;
    }
    _log(
      event,
      [
        if (itemId != null) 'item=$itemId',
        if (elapsed != null) 'elapsedMs=${elapsed.inMilliseconds}',
        if (details != null && details.isNotEmpty) details,
      ].join(' '),
    );
  }

  static void _log(String event, String details) {
    if (kReleaseMode && !enabled) {
      return;
    }
    debugPrint('[player-rebuild] $event $details');
  }
}
