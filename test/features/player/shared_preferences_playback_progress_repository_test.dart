import 'package:drama_client/features/player/data/shared_preferences_playback_progress_repository.dart';
import 'package:drama_client/features/player/domain/player_playback_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cleanup ignores legacy non-string progress keys', () async {
    SharedPreferences.setMockInitialValues({
      'player.playback_progress.cleanup_at_ms': 1,
      'player.playback_progress_cleanup_at_ms': 0,
    });

    final repository = SharedPreferencesPlaybackProgressRepository();

    await repository.saveProgress(
      PlaybackProgress(
        itemId: 'single:720:2848',
        position: const Duration(seconds: 81),
        duration: const Duration(seconds: 161),
        updatedAt: DateTime.now(),
      ),
    );

    final progress = await repository.getProgress('single:720:2848');

    expect(progress?.position, const Duration(seconds: 81));
  });
}
