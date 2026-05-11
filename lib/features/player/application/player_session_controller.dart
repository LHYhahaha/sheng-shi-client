import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerSessionController {
  PlayerSessionController() : player = Player() {
    videoController = VideoController(player);
  }

  final Player player;
  late final VideoController videoController;

  Future<void> open(String url) {
    return player.open(Media(url));
  }

  Future<void> dispose() {
    return player.dispose();
  }
}
