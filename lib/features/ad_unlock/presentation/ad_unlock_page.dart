import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics/analytics_provider.dart';
import '../../../core/toast/app_center_toast.dart';
import '../application/ad_effective_watch_controller.dart';
import '../application/ad_unlock_analytics_tracker.dart';
import '../application/ad_unlock_session_controller.dart';
import '../data/ad_unlock_repository_provider.dart';
import '../domain/ad_unlock_models.dart';

class AdUnlockRouteResult {
  const AdUnlockRouteResult.confirmed({required this.refreshFuture});

  final Future<bool> refreshFuture;
}

class AdUnlockPage extends ConsumerStatefulWidget {
  const AdUnlockPage({
    required this.session,
    required this.dramaId,
    required this.episodeId,
    this.onUnlockConfirmed,
    super.key,
  });

  final AdUnlockSession session;
  final String dramaId;
  final String episodeId;
  final Future<bool> Function()? onUnlockConfirmed;

  @override
  ConsumerState<AdUnlockPage> createState() => _AdUnlockPageState();
}

class _AdUnlockPageState extends ConsumerState<AdUnlockPage>
    with WidgetsBindingObserver {
  late final AdEffectiveWatchController _watch;
  late final AdUnlockSessionController _sessionController;
  late final AdUnlockAnalyticsTracker _analyticsTracker;
  Player? _player;
  VideoController? _videoController;
  Timer? _ticker;
  Future<bool>? _refreshFuture;
  bool _materialLoadFailed = false;
  bool _sessionInvalid = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watch = AdEffectiveWatchController(
      requiredSeconds: widget.session.watchSeconds,
    );
    _sessionController =
        AdUnlockSessionController(
            repository: ref.read(adUnlockRepositoryProvider),
          )
          ..session = widget.session
          ..state = AdUnlockSessionState.watching;
    _analyticsTracker = AdUnlockAnalyticsTracker(
      analytics: ref.read(analyticsServiceProvider),
      adSessionId: widget.session.sessionNo,
      adMaterialId: widget.session.material.id.toString(),
      dramaId: widget.dramaId,
      episodeId: widget.episodeId,
    );
    if (widget.session.material.type == AdMaterialType.video) {
      final player = Player();
      _player = player;
      _videoController = VideoController(player);
      player.stream.playing.listen((value) {
        _watch.setMaterialVisible(value);
        if (value) {
          unawaited(_analyticsTracker.markMaterialVisible());
        }
      });
      unawaited(_openVideoMaterial(player));
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  String get _materialSource =>
      widget.session.materialFilePath ?? widget.session.material.fileUrl;

  Future<void> _openVideoMaterial(Player player) async {
    // A material can be shorter than the server-required watch duration.
    // Keep it playing until the effective watch time reaches that duration.
    await player.setPlaylistMode(PlaylistMode.loop);
    try {
      await player.open(Media(_materialSource), play: true);
    } catch (_) {
      _reportMaterialLoadFailure();
    }
  }

  void _reportMaterialVisible() {
    _watch.setMaterialVisible(true);
    unawaited(_analyticsTracker.markMaterialVisible());
  }

  void _reportMaterialLoadFailure() {
    if (_materialLoadFailed) return;
    _materialLoadFailed = true;
    _watch.setMaterialVisible(false);
    unawaited(
      _analyticsTracker.finish(
        watchedDuration: _watch.watchedDuration,
        materialLoadFailed: true,
      ),
    );
  }

  void _tick() {
    if (!mounted || _sessionController.state != AdUnlockSessionState.watching) {
      return;
    }
    if (_watch.isComplete) {
      unawaited(_confirm());
    }
    setState(() {});
  }

  Future<void> _confirm() async {
    await _sessionController.confirm(watchSeconds: _watch.watchedSeconds);
    if (!mounted) return;
    if (_sessionController.state == AdUnlockSessionState.confirmed) {
      _onUnlockConfirmed();
      return;
    }
    _sessionInvalid =
        DateTime.now().isAfter(widget.session.expiresAt) ||
        _sessionController.hasSessionInvalidError;
    if (_sessionInvalid) {
      unawaited(
        _analyticsTracker.finish(
          watchedDuration: _watch.watchedDuration,
          sessionInvalid: true,
        ),
      );
    }
    setState(() {});
  }

  Future<void> _retry() async {
    await _sessionController.retryConfirmation();
    if (!mounted) return;
    if (_sessionController.state == AdUnlockSessionState.confirmed) {
      _onUnlockConfirmed();
      return;
    }
    _sessionInvalid =
        DateTime.now().isAfter(widget.session.expiresAt) ||
        _sessionController.hasSessionInvalidError;
    if (_sessionInvalid) {
      unawaited(
        _analyticsTracker.finish(
          watchedDuration: _watch.watchedDuration,
          sessionInvalid: true,
        ),
      );
    }
    setState(() {});
  }

  Future<void> _openH5() async {
    final value = widget.session.h5Url;
    if (value == null || value.isEmpty) return;
    _watch.setExternalH5Open(true);
    await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
  }

  void _closeAfterUnlock() {
    final refreshFuture = _refreshFuture;
    if (_sessionController.state != AdUnlockSessionState.confirmed ||
        refreshFuture == null) {
      return;
    }
    Navigator.of(
      context,
    ).pop(AdUnlockRouteResult.confirmed(refreshFuture: refreshFuture));
  }

  void _onUnlockConfirmed() {
    _refreshFuture ??=
        widget.onUnlockConfirmed?.call() ?? Future<bool>.value(true);
    showAppCenterToast('解锁成功');
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _watch.setAppForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      _watch.setExternalH5Open(false);
    }
    if (state != AppLifecycleState.resumed &&
        widget.session.material.type == AdMaterialType.video) {
      unawaited(_player?.pause());
    }
  }

  @override
  void dispose() {
    unawaited(
      _analyticsTracker.finish(
        watchedDuration: _watch.watchedDuration,
        materialLoadFailed: _materialLoadFailed,
        sessionInvalid:
            _sessionInvalid || DateTime.now().isAfter(widget.session.expiresAt),
        reachedRequiredWatchTime: _watch.isComplete,
      ),
    );
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retry = _sessionController.state == AdUnlockSessionState.confirmRetry;
    final unlocked = _sessionController.state == AdUnlockSessionState.confirmed;
    final seconds = _watch.watchedSeconds;
    final required = widget.session.watchSeconds;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 112,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 12),
                    child: GestureDetector(
                      onTap: unlocked ? _closeAfterUnlock : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: unlocked
                            ? Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              )
                            : Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  children: [
                                    const TextSpan(text: 'Close in '),
                                    TextSpan(
                                      text:
                                          '${(required - seconds).clamp(0, required)}s',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: widget.session.h5Url?.isNotEmpty == true
                      ? _openH5
                      : null,
                  child: widget.session.material.type == AdMaterialType.video
                      ? Video(
                          controller: _videoController!,
                          controls: NoVideoControls,
                          fit: BoxFit.contain,
                        )
                      : widget.session.materialFilePath == null
                      ? Image.network(
                          widget.session.material.fileUrl,
                          fit: BoxFit.contain,
                          frameBuilder: (context, child, frame, wasSync) {
                            if (frame != null || wasSync) {
                              _reportMaterialVisible();
                            }
                            return child;
                          },
                          errorBuilder: (context, error, stackTrace) {
                            _reportMaterialLoadFailure();
                            return const ColoredBox(color: Color(0xFF242424));
                          },
                        )
                      : Image.file(
                          File(widget.session.materialFilePath!),
                          fit: BoxFit.contain,
                          frameBuilder: (context, child, frame, wasSync) {
                            if (frame != null || wasSync) {
                              _reportMaterialVisible();
                            }
                            return child;
                          },
                          errorBuilder: (context, error, stackTrace) {
                            _reportMaterialLoadFailure();
                            return const ColoredBox(color: Color(0xFF242424));
                          },
                        ),
                ),
              ),
              SizedBox(
                height: 98,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        minHeight: 4,
                        value: required == 0 ? 1 : seconds / required,
                        color: const Color(0xFFFF007A),
                        backgroundColor: const Color(0x4DFFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: retry || unlocked
                                ? Text(
                                    retry
                                        ? 'Unlock confirmation failed'
                                        : 'Unlocked successfully',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  )
                                : Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      children: [
                                        const TextSpan(text: 'Watch '),
                                        TextSpan(
                                          text:
                                              '${(required - seconds).clamp(0, required)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: 's more to unlock',
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unlocked ? 'Unlocked' : 'Watching',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                        ],
                      ),
                      if (retry)
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Retry unlock'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
