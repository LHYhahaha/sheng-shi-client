import 'package:drama_client/features/home/application/home_player_entry_intent.dart';
import 'package:drama_client/features/drama/domain/drama.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home drama with watch progress builds resumable player intent', () {
    final intent = buildHomePlayerEntryIntent(
      drama: _drama(
        watchProgress: const DramaWatchProgress(
          episodeId: '8604',
          episodeNo: 3,
          positionSeconds: 35,
          durationSeconds: 126,
        ),
      ),
      userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(intent.dramaId, '799');
    expect(intent.episodeId, '8604');
    expect(intent.trigger, 'home_card_tap');
    expect(intent.targetItemId, 'single:799:8604');
    expect(intent.resumeProgress?.itemId, 'single:799:8604');
    expect(intent.resumeProgress?.position, const Duration(seconds: 35));
    expect(intent.resumeProgress?.duration, const Duration(seconds: 126));
  });

  test('near-ended home progress opens default episode without resume', () {
    final intent = buildHomePlayerEntryIntent(
      drama: _drama(
        watchProgress: const DramaWatchProgress(
          episodeId: '8604',
          episodeNo: 3,
          positionSeconds: 125,
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

Drama _drama({DramaWatchProgress? watchProgress}) {
  return Drama(
    id: '799',
    title: 'Drama',
    coverAssetPath: Drama.fallbackCoverAssetPath,
    viewCountLabel: '',
    episodeCount: 80,
    categoryId: 'home',
    tags: const [],
    coverAspectRatio: 0.7,
    watchProgress: watchProgress,
  );
}
