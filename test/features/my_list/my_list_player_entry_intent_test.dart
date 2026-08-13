import 'package:drama_client/features/my_list/application/my_list_player_entry_intent.dart';
import 'package:drama_client/features/my_list/domain/my_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'collection item opens displayed episode number instead of stale id',
    () {
      final intent = buildMyListPlayerEntryIntent(
        item: const MyListItem(
          dramaId: 1508,
          title: 'Drama',
          introduction: '',
          coverAssetPath: MyListItem.fallbackCoverAssetPath,
          currentEpisode: 1,
          episodeCount: 8,
          episodeId: 13646,
        ),
        isCollection: true,
        userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(intent.dramaId, '1508');
      expect(intent.episodeId, '1');
      expect(intent.episodeNo, 1);
      expect(intent.trigger, 'my_list_collection_item');
      expect(intent.targetItemId, 'single:1508:1');
      expect(intent.resumeProgress, isNull);
    },
  );

  test(
    'play history item builds player intent with immediate resume progress',
    () {
      final intent = buildMyListPlayerEntryIntent(
        item: const MyListItem(
          dramaId: 799,
          title: 'Drama',
          introduction: '',
          coverAssetPath: MyListItem.fallbackCoverAssetPath,
          currentEpisode: 12,
          episodeCount: 80,
          episodeId: 14327,
          watchSecond: 35,
          durationSecond: 126,
        ),
        isCollection: false,
        userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(intent.dramaId, '799');
      expect(intent.episodeId, '14327');
      expect(intent.trigger, 'play_history_item');
      expect(intent.targetItemId, 'single:799:14327');
      expect(intent.resumeProgress?.itemId, 'single:799:14327');
      expect(intent.resumeProgress?.position, const Duration(seconds: 35));
      expect(intent.resumeProgress?.duration, const Duration(seconds: 126));
    },
  );

  test(
    'near-ended history progress stays on current episode without resume',
    () {
      final intent = buildMyListPlayerEntryIntent(
        item: const MyListItem(
          dramaId: 799,
          title: 'Drama',
          introduction: '',
          coverAssetPath: MyListItem.fallbackCoverAssetPath,
          currentEpisode: 12,
          episodeCount: 80,
          episodeId: 14327,
          watchSecond: 125,
          durationSecond: 126,
        ),
        isCollection: false,
        userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      expect(intent.episodeId, '14327');
      expect(intent.targetItemId, 'single:799:14327');
      expect(intent.resumeProgress, isNull);
    },
  );

  test('near-ended last episode stays on current episode without resume', () {
    final intent = buildMyListPlayerEntryIntent(
      item: const MyListItem(
        dramaId: 799,
        title: 'Drama',
        introduction: '',
        coverAssetPath: MyListItem.fallbackCoverAssetPath,
        currentEpisode: 80,
        episodeCount: 80,
        episodeId: 99999,
        watchSecond: 125,
        durationSecond: 126,
      ),
      isCollection: false,
      userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(intent.episodeId, '99999');
    expect(intent.targetItemId, 'single:799:99999');
    expect(intent.resumeProgress, isNull);
  });

  test('history item without episode id opens first episode explicitly', () {
    final intent = buildMyListPlayerEntryIntent(
      item: const MyListItem(
        dramaId: 799,
        title: 'Drama',
        introduction: '',
        coverAssetPath: MyListItem.fallbackCoverAssetPath,
        currentEpisode: 0,
        episodeCount: 80,
      ),
      isCollection: false,
      userActionAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(intent.episodeId, '1');
    expect(intent.episodeNo, 1);
    expect(intent.targetItemId, 'single:799:1');
    expect(intent.resumeProgress, isNull);
  });
}
