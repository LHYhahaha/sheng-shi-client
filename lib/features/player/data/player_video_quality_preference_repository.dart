import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PlayerVideoQualityPreferenceRepository {
  Future<String> read();
  Future<void> save(String qualityId);
}

class SharedPreferencesPlayerVideoQualityPreferenceRepository
    implements PlayerVideoQualityPreferenceRepository {
  static const _key = 'player.video_quality.preference';

  @override
  Future<String> read() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key) ?? 'auto';
    } catch (_) {
      return 'auto';
    }
  }

  @override
  Future<void> save(String qualityId) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, qualityId);
    } catch (_) {
      // A failed local write must not block a successful playback switch.
    }
  }
}
