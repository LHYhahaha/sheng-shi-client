import 'package:drama_client/features/player/data/mock_player_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockPlayerContentRepository', () {
    test('keeps remote HLS video metadata for mock playback', () {
      expect(mockPlayerVideoAssets.length, 5);

      for (final asset in mockPlayerVideoAssets) {
        expect(asset.title, isNotEmpty);
        expect(asset.sourceName, isNotEmpty);
        expect(asset.sourcePage, startsWith('https://'));
        expect(asset.licenseNote, contains('testing and development'));
        expect(asset.videoUrl, startsWith('https://'));
        expect(asset.videoUrl, endsWith('/index.m3u8'));
      }
    });

    test('uses HLS mock videos across generated episodes', () async {
      final content = await const MockPlayerContentRepository()
          .getPlayerContent(dramaId: 'found-you');

      expect(
        content.episodes.first.videoUrl,
        mockPlayerVideoAssets.first.videoUrl,
      );
      expect(
        content.episodes[mockPlayerVideoAssets.length].videoUrl,
        mockPlayerVideoAssets.first.videoUrl,
      );
      expect(
        content.episodes.take(mockPlayerVideoAssets.length).map((episode) {
          return episode.videoUrl;
        }),
        mockPlayerVideoAssets.map((asset) => asset.videoUrl),
      );
    });
  });
}
