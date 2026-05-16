import 'package:drama_client/features/player/data/mock_player_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockPlayerContentRepository', () {
    test('keeps remote HLS video metadata for mock playback', () {
      expect(mockPlayerVideoAssets.length, greaterThanOrEqualTo(20));

      for (final asset in mockPlayerVideoAssets) {
        expect(asset.sourceLabel, isNotEmpty);
        expect(asset.title, isNotEmpty);
        expect(asset.sourceName, isNotEmpty);
        expect(asset.sourcePage, startsWith('https://'));
        expect(asset.licenseNote, contains('testing and development'));
        expect(asset.videoUrl, startsWith('https://'));
        expect(asset.videoUrl, endsWith('.m3u8'));
        expect(asset.videoUrl, isNot(contains('.mp4')));
        expect(asset.aspectRatio, greaterThan(0));
      }

      expect(
        mockPlayerVideoAssets.map((asset) => asset.videoUrl).toSet(),
        hasLength(mockPlayerVideoAssets.length),
      );
      expect(
        mockPlayerVideoAssets.map((asset) => asset.videoUrl),
        containsAllInOrder(const [
          'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          'https://test-streams.mux.dev/tos_ismc/main.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear2/prog_index.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear3/prog_index.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear4/prog_index.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear2/prog_index.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear3/prog_index.m3u8',
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear4/prog_index.m3u8',
          'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8',
          'https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8',
          'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
          'https://content.jwplatform.com/manifests/vM7nH0Kl.m3u8',
          'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
          'https://test-streams.mux.dev/test_001/stream.m3u8',
          'https://test-streams.mux.dev/pts_shift/master.m3u8',
          'https://test-streams.mux.dev/dai-discontinuity-deltatre/manifest.m3u8',
          'https://test-streams.mux.dev/issue666/playlists/cisq0gim60007xzvi505emlxx.m3u8',
        ]),
      );
      expect(
        mockPlayerVideoAssets.map((asset) => asset.sourceLabel),
        containsAllInOrder(const [
          'mux-fast',
          'mux-tears-stable',
          'apple-bipbop-low-stable',
          'aspect-ratio-16x9-test',
          'aspect-ratio-4x3-test',
          'apple-bipbop-advanced-ts-test',
          'apple-bipbop-16x9-gear2-test',
          'apple-bipbop-16x9-gear3-test',
          'apple-bipbop-16x9-gear4-test',
          'apple-bipbop-4x3-gear1-test',
          'apple-bipbop-4x3-gear2-test',
          'apple-bipbop-4x3-gear3-test',
          'apple-bipbop-4x3-gear4-test',
          'shaka-angel-one-test',
          'shaka-bbb-dark-truths-test',
          'akamai-live-hls-test',
          'unstable-source-test',
          'slow-source-test',
          'mux-arte-china-test',
          'mux-pts-shift-test',
          'mux-ad-discontinuity-test',
          'mux-issue666-test',
        ]),
      );
    });

    test('uses stable public HLS fixtures for the first three episodes', () async {
      final content = await const MockPlayerContentRepository()
          .getPlayerContent(dramaId: 'found-you');

      expect(content.episodes.take(3).map((episode) => episode.videoUrl), const [
        'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        'https://test-streams.mux.dev/tos_ismc/main.m3u8',
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8',
      ]);
      expect(
        content.episodes.take(3).map((episode) => episode.videoUrl).toSet(),
        hasLength(3),
      );
      expect(
        content.episodes.take(3).map((episode) => episode.videoAspectRatio),
        const [16 / 9, 16 / 9, 16 / 9],
      );
    });

    test(
      'uses staged locked prices to cover coin and recharge sheets',
      () async {
        final content = await const MockPlayerContentRepository()
            .getPlayerContent(dramaId: 'found-you');

        expect(content.episodes[3].requiredCoins, 60);
        expect(content.episodes[4].requiredCoins, 6000);
        expect(content.episodes[5].requiredCoins, 8000);
        expect(content.episodes[7].requiredCoins, 10000);
      },
    );

    test('default episode chain only cycles stable HLS fixtures', () async {
      final content = await const MockPlayerContentRepository()
          .getPlayerContent(dramaId: 'found-you');

      expect(
        content.episodes.first.videoUrl,
        defaultMockPlayerVideoAssets.first.videoUrl,
      );
      expect(
        content.episodes[defaultMockPlayerVideoAssets.length].videoUrl,
        defaultMockPlayerVideoAssets.first.videoUrl,
      );
      expect(
        content.episodes.take(9).map((episode) {
          return episode.videoUrl;
        }),
        [
          ...defaultMockPlayerVideoAssets.map((asset) => asset.videoUrl),
          ...defaultMockPlayerVideoAssets.map((asset) => asset.videoUrl),
          ...defaultMockPlayerVideoAssets.map((asset) => asset.videoUrl),
        ],
      );
      expect(
        content.episodes.map((episode) => episode.videoUrl).toSet(),
        defaultMockPlayerVideoAssets.map((asset) => asset.videoUrl).toSet(),
      );
      expect(
        content.episodes.map((episode) => episode.videoUrl),
        isNot(contains(mockPlayerVideoAssets[3].videoUrl)),
      );
    });
  });
}
