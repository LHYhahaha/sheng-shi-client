import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/player_content.dart';

/// 广告页的返回结果。实际接入时，仅应在服务端完成广告任务后返回 completed。
class AdUnlockResult {
  const AdUnlockResult.completed();
}

/// 与短剧播放会话隔离的全屏广告播放器。
///
/// 广告视频 URL 由 `ad_unlock` 下发；未接广告素材接口前，页面仍可用于验收 UI 和计时流程。
class AdUnlockPage extends StatefulWidget {
  const AdUnlockPage({required this.offer, super.key});

  final PlayerAdUnlockOffer offer;

  @override
  State<AdUnlockPage> createState() => _AdUnlockPageState();
}

class _AdUnlockPageState extends State<AdUnlockPage>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _isPlaying = false;

  bool get _canClose => _remaining <= Duration.zero;
  bool get _hasVideo =>
      widget.offer.adVideoUrl != null && widget.offer.adVideoUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remaining = widget.offer.closeAfter;
    _player = Player();
    _videoController = VideoController(_player);
    _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      _syncCountdown();
    });
    if (_hasVideo) {
      unawaited(_player.open(Media(widget.offer.adVideoUrl!), play: true));
    } else {
      // 开发和接口联调阶段没有广告素材时，仍可验收广告倒计时 UI。
      _isPlaying = true;
      _syncCountdown();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_player.pause());
    }
  }

  void _syncCountdown() {
    _countdownTimer?.cancel();
    if (!_isPlaying || _canClose) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isPlaying || _canClose) return;
      setState(() => _remaining -= const Duration(seconds: 1));
      if (_canClose) _syncCountdown();
    });
  }

  void _close() {
    if (!_canClose) return;
    // TODO(ad API): 调用广告任务完成接口，服务端确认后再返回 completed。
    Navigator.of(context).pop(const AdUnlockResult.completed());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _remaining.inSeconds.clamp(0, 999);
    final required = widget.offer.closeAfter.inSeconds;
    final progress = required <= 0 ? 1.0 : 1 - seconds / required;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              bottom: 70,
              child: _hasVideo
                  ? Video(controller: _videoController, fit: BoxFit.contain)
                  : const _AdVideoPlaceholder(),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: TextButton(
                key: const ValueKey('ad_unlock_close_button'),
                onPressed: _canClose ? _close : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFFCDCDCD),
                  backgroundColor: const Color(0xFF424242),
                  disabledBackgroundColor: const Color(0xFF424242),
                  shape: const StadiumBorder(
                    side: BorderSide(color: Color(0xFF777777)),
                  ),
                ),
                child: Text(_canClose ? 'Close' : 'Close in ${seconds}s'),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 4,
                      backgroundColor: const Color(0xFF656565),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color(0xFFB8B8B8),
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: 'Watch '),
                              TextSpan(
                                text: '${seconds}s',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const TextSpan(text: ' more to unlock'),
                            ],
                          ),
                        ),
                      ),
                      const _WatchingBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdVideoPlaceholder extends StatelessWidget {
  const _AdVideoPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF242424),
    child: Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: Colors.white38,
        size: 52,
      ),
    ),
  );
}

class _WatchingBadge extends StatelessWidget {
  const _WatchingBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF424242),
      border: Border.all(color: const Color(0xFF777777)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Watching',
      style: TextStyle(color: Color(0xFFB8B8B8), fontSize: 14),
    ),
  );
}
