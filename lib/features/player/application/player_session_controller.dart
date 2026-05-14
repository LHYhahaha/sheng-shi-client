import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

abstract interface class PlayerPlaybackSession {
  VideoController? get videoController;

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
