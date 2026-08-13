import 'package:drama_client/features/player/data/shared_preferences_drama_playback_target_repository.dart';
import 'package:drama_client/features/player/domain/drama_playback_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'save and read preserves episode number for resume target matching',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPreferencesDramaPlaybackTargetRepository();

      await repository.save(
        DramaPlaybackTarget(
          dramaId: '1508',
          episodeId: 'stale-episode-id',
          episodeNo: 3,
          position: const Duration(seconds: 35),
          duration: const Duration(seconds: 120),
          updatedAt: DateTime.now(),
        ),
      );

      final target = await repository.getForDrama('1508');

      expect(target?.episodeId, 'stale-episode-id');
      expect(target?.episodeNo, 3);
      expect(target?.position, const Duration(seconds: 35));
    },
  );
}
