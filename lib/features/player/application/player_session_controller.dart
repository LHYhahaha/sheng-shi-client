import 'dart:developer' as developer;

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 播放器 session 抽象。
///
/// 控制器只依赖这个接口，避免直接绑定 media_kit，测试也可以注入 fake session。
/// 所有 stream 都描述当前 media session，不包含 HLS preload 状态。
abstract interface class PlayerPlaybackSession {
  /// UI 渲染视频画面所需的 controller。
  ///
  /// session dispose 后不能继续使用。
  VideoController? get videoController;

  /// 当前 media session 是否缓冲。
  Stream<bool> get bufferingStream;

  /// 当前 media session 是否正在播放。
  Stream<bool> get playingStream;

  /// 当前 media 是否自然结束。
  Stream<bool> get completedStream;

  /// 当前播放位置。
  Stream<Duration> get positionStream;

  /// 当前媒体总时长。
  Stream<Duration> get durationStream;

  /// 当前缓冲位置。
  Stream<Duration> get bufferedPositionStream;

  /// 当前播放倍速。
  Stream<double> get rateStream;

  /// 当前视频宽度。
  ///
  /// width > 0 被用作首帧到达信号。
  Stream<int?> get widthStream;

  /// 底层播放器错误流。
  ///
  /// 控制器会分类成业务错误，不要直接展示原始字符串。
  Stream<String> get errorStream;

  /// 打开 source。
  ///
  /// `play=true` 会立即开始播放；prepare warm-up 也会用静音 play 触发解码。
  Future<void> open(
    String source, {
    bool play = true,
    Duration? start,
    Map<String, String>? httpHeaders,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setRate(double rate);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// media_kit 的 PlayerPlaybackSession 实现。
///
/// 这一层只做 API 适配，不做业务判断。播放状态机、预热窗口和错误分类都在
/// PlayerPlaybackController。
class MediaKitPlayerSession implements PlayerPlaybackSession {
  MediaKitPlayerSession() : player = Player() {
    videoController = VideoController(player);
  }

  /// 底层 media_kit player。
  ///
  /// 只在 session 内部持有，外部不要直接操作，避免绕过控制器状态机。
  final Player player;
  @override
  late final VideoController videoController;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  Stream<bool> get playingStream => player.stream.playing;

  @override
  Stream<bool> get completedStream => player.stream.completed;

  @override
  Stream<Duration> get positionStream => player.stream.position;

  @override
  Stream<Duration> get durationStream => player.stream.duration;

  @override
  Stream<Duration> get bufferedPositionStream => player.stream.buffer;

  @override
  Stream<double> get rateStream => player.stream.rate;

  @override
  Stream<int?> get widthStream => player.stream.width;

  @override
  Stream<String> get errorStream => player.stream.error;

  @override
  Future<void> open(
    String source, {
    bool play = true,
    Duration? start,
    Map<String, String>? httpHeaders,
  }) async {
    developer.log(
      'MediaKitPlayerSession: 开始打开视频 - source=$source, play=$play, start=$start',
    );
    try {
      final media = Media(source, start: start, httpHeaders: httpHeaders);
      developer.log('MediaKitPlayerSession: Media 对象已创建，${media.end}');
      await player.open(media, play: play);
      developer.log('MediaKitPlayerSession: 视频打开成功 - source=$source');
    } catch (e, st) {
      developer.log(
        'MediaKitPlayerSession: 视频打开失败 - source=$source, error=$e\n$st',
      );
      rethrow;
    }
  }

  @override
  Future<void> play() {
    developer.log('MediaKitPlayerSession: play');
    return player.play();
  }

  @override
  Future<void> pause() {
    developer.log('MediaKitPlayerSession: pause');
    return player.pause();
  }

  @override
  Future<void> seek(Duration position) {
    developer.log('MediaKitPlayerSession: seek - position=$position');
    return player.seek(position);
  }

  @override
  Future<void> setRate(double rate) {
    return player.setRate(rate);
  }

  @override
  Future<void> setVolume(double volume) {
    return player.setVolume(volume);
  }

  @override
  Future<void> dispose() {
    return player.dispose();
  }
}
