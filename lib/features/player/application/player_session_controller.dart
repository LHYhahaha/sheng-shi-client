import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

abstract interface class PlayerPlaybackSession {
  VideoController? get videoController;

  Stream<bool> get bufferingStream;

  Stream<int?> get widthStream;

  Stream<String> get errorStream;

  Future<void> open(String source, {bool play = true});

  Future<void> play();

  Future<void> pause();

  Future<void> dispose();
}

class MediaKitPlayerSession implements PlayerPlaybackSession {
  MediaKitPlayerSession() : player = Player() {
    videoController = VideoController(player);
  }

  final Player player;
  @override
  late final VideoController videoController;

  @override
  Stream<bool> get bufferingStream => player.stream.buffering;

  @override
  Stream<int?> get widthStream => player.stream.width;

  @override
  Stream<String> get errorStream => player.stream.error;

  @override
  Future<void> open(String source, {bool play = true}) {
    return player.open(Media(source), play: play);
  }

  @override
  Future<void> play() {
    return player.play();
  }

  @override
  Future<void> pause() {
    return player.pause();
  }

  @override
  Future<void> dispose() {
    return player.dispose();
  }
}
