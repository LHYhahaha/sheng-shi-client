import 'package:drama_client/features/home/domain/home_data.dart';
import 'package:drama_client/features/search/application/search_player_entry_intent.dart';
import 'package:drama_client/features/search/domain/search_results.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search result with watch progress builds resumable player intent', () {
    final intent = buildSearchPlayerEntryIntent(
      drama: _drama(
        watchProgress: const HomeWatchProgress(
          episodeId: '8604',
          episodeNo: 3,
          positionSeconds: 35,
          progressPercent: 28,
          durationSeconds: 126,
        ),
      ),
      userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(intent.dramaId, '799');
    expect(intent.episodeId, '8604');
    expect(intent.trigger, 'search_result_tap');
    expect(intent.targetItemId, 'single:799:8604');
    expect(intent.resumeProgress?.itemId, 'single:799:8604');
    expect(intent.resumeProgress?.position, const Duration(seconds: 35));
    expect(intent.resumeProgress?.duration, const Duration(seconds: 126));
  });

  test('near-ended search progress opens default episode without resume', () {
    final intent = buildSearchPlayerEntryIntent(
      drama: _drama(
        watchProgress: const HomeWatchProgress(
          episodeId: '8604',
          episodeNo: 3,
          positionSeconds: 125,
          progressPercent: 99,
          durationSeconds: 126,
        ),
      ),
      userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(intent.episodeId, '1');
    expect(intent.episodeNo, 1);
    expect(intent.targetItemId, 'single:799:1');
    expect(intent.resumeProgress, isNull);
  });
}

SearchResultDrama _drama({HomeWatchProgress? watchProgress}) {
  return SearchResultDrama(
    id: '799',
    sort: 1,
    coverUrl: '',
    title: 'Drama',
    summary: '',
    tags: const [],
    categories: const [],
    playCount: 0,
    trailerEpisodeNum: 0,
    isVipOnly: false,
    status: 1,
    episodeTotal: 80,
    watchProgress: watchProgress,
  );
}
