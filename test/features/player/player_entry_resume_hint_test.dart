import 'package:drama_client/features/drama/domain/drama_watch_progress.dart';
import 'package:drama_client/features/player/application/player_entry_preload_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a player entry hint from valid list watch progress', () {
    final hint = playerEntryResumeHintFor(
      const DramaWatchProgress(
        episodeId: '8519',
        episodeNo: 12,
        positionSeconds: 74,
        progressPercent: 34,
        durationSeconds: 217,
      ),
    );

    expect(hint!.episodeId, '8519');
    expect(hint.episodeNo, 12);
    expect(hint.position, const Duration(seconds: 74));
    expect(hint.duration, const Duration(seconds: 217));
  });

  test('does not create a player entry hint for a new drama', () {
    final hint = playerEntryResumeHintFor(
      const DramaWatchProgress(
        episodeId: '0',
        episodeNo: 0,
        positionSeconds: 0,
        progressPercent: 0,
        durationSeconds: 0,
      ),
    );

    expect(hint, isNull);
  });
}
