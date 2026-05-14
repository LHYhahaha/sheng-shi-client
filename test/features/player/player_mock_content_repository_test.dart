import 'package:drama_client/features/player/data/mock_player_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockPlayerContentRepository', () {
    test('keeps remote HLS video metadata for mock playback', () {
      expect(mockPlayerVideoAssets.length, 3);

      for (final asset in mockPlayerVideoAssets) {
        expect(asset.sourceLabel, isNotEmpty);
        expect(asset.title, isNotEmpty);
        expect(asset.sourceName, isNotEmpty);
        expect(asset.sourcePage, startsWith('https://'));
        expect(asset.licenseNote, contains('testing and development'));
        expect(asset.videoUrl, startsWith('https://'));
        expect(asset.videoUrl, contains('.m3u8'));
      }

      expect(
        mockPlayerVideoAssets.map((asset) => asset.videoUrl).toSet(),
        hasLength(mockPlayerVideoAssets.length),
      );
      expect(
        mockPlayerVideoAssets.map((asset) => asset.videoUrl),
        containsAllInOrder(const [
          'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
          'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        ]),
      );
      expect(
        mockPlayerVideoAssets.map((asset) => asset.sourceLabel),
        containsAllInOrder(const [
          'unified-tears-slow',
          'apple-bipbop',
          'mux-x36',
        ]),
      );
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
