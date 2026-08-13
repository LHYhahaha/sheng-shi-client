import 'package:drama_client/features/player/domain/initial_playback_intent.dart';
import 'package:drama_client/features/player/domain/player_playback_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single drama intent carries resumable progress for target item', () {
    final progress = PlaybackProgress(
      itemId: 'single:799:14327',
      position: const Duration(seconds: 35),
      duration: const Duration(seconds: 126),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(900),
    );

    final intent = InitialPlaybackIntent.singleDrama(
      dramaId: '799',
      episodeId: '14327',
      trigger: 'play_history_item',
      userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
      resumeProgress: progress,
    );

    expect(intent.targetItemId, 'single:799:14327');
    expect(intent.resumeProgress?.canResume, isTrue);
    expect(intent.resumeProgress?.position, const Duration(seconds: 35));
  });

  test(
    'can carry an explicit episode number distinct from route episode id',
    () {
      final intent = InitialPlaybackIntent.singleDrama(
        dramaId: '1508',
        episodeId: '1',
        episodeNo: 3,
        trigger: 'my_list_collection_item',
        userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(intent.episodeId, '1');
      expect(intent.episodeNo, 3);
      expect(intent.targetItemId, 'single:1508:1');
    },
  );
}
