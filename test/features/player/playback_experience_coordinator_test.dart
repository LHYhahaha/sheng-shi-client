import 'package:drama_client/features/player/application/playback_experience_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('experience target equality includes feed revision and episode', () {
    expect(
      const PlaybackExperienceTarget(
        itemId: 'for-you-item',
        episodeId: 'episode-1',
        feedRevision: 1,
      ),
      isNot(
        const PlaybackExperienceTarget(
          itemId: 'for-you-item',
          episodeId: 'episode-1',
          feedRevision: 2,
        ),
      ),
    );
  });
}
