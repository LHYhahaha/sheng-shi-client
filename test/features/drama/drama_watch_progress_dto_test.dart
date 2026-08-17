import 'package:drama_client/features/drama/data/dto/drama_watch_progress_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a list drama resume target from snake case payload', () {
    const payload = <String, Object?>{
      'watch_episode_id': 8519,
      'watch_episode_no': 12,
      'watch_second': 74,
      'progress_percent': 34,
      'duration_second': 217,
    };

    final progress = DramaWatchProgressDto.fromJsonOrNull(payload)!.toDomain();

    expect(progress.episodeId, '8519');
    expect(progress.episodeNo, 12);
    expect(progress.positionSeconds, 74);
    expect(progress.progressPercent, 34);
    expect(progress.durationSeconds, 217);
  });

  test(
    'keeps an all-zero progress object as a non-resumable new-drama state',
    () {
      final progress =
          DramaWatchProgressDto.fromJsonOrNull(const <String, Object?>{
            'watch_episode_id': 0,
            'watch_episode_no': 0,
            'watch_second': 0,
            'progress_percent': 0,
            'duration_second': 0,
          })!.toDomain();

      expect(progress.canResume, isFalse);
    },
  );

  test('ignores a malformed progress value', () {
    expect(DramaWatchProgressDto.fromJsonOrNull('invalid'), isNull);
  });
}
