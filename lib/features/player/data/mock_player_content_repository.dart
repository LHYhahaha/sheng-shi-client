import '../../entitlement/domain/episode_unlock_type.dart';
import '../domain/player_content.dart';

const mockPlayerVideoAssets = [
  MockPlayerVideoAsset(
    sourceLabel: 'mux-fast',
    title: 'Mux x36xhzz HLS',
    sourceName: 'Mux Test Streams',
    sourcePage: 'https://test-streams.mux.dev/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'mux-tears-stable',
    title: 'Mux Tears of Steel HLS',
    sourceName: 'Mux Test Streams',
    sourcePage: 'https://test-streams.mux.dev/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl: 'https://test-streams.mux.dev/tos_ismc/main.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-low-stable',
    title: 'Apple BipBop Low HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'aspect-ratio-16x9-test',
    title: 'Apple BipBop 16x9 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'aspect-ratio-4x3-test',
    title: 'Apple BipBop 4x3 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8',
    aspectRatio: 4 / 3,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-advanced-ts-test',
    title: 'Apple BipBop Advanced TS HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-16x9-gear2-test',
    title: 'Apple BipBop 16x9 Gear 2 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear2/prog_index.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-16x9-gear3-test',
    title: 'Apple BipBop 16x9 Gear 3 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear3/prog_index.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-16x9-gear4-test',
    title: 'Apple BipBop 16x9 Gear 4 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear4/prog_index.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-4x3-gear1-test',
    title: 'Apple BipBop 4x3 Gear 1 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8',
    aspectRatio: 4 / 3,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-4x3-gear2-test',
    title: 'Apple BipBop 4x3 Gear 2 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear2/prog_index.m3u8',
    aspectRatio: 4 / 3,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-4x3-gear3-test',
    title: 'Apple BipBop 4x3 Gear 3 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear3/prog_index.m3u8',
    aspectRatio: 4 / 3,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'apple-bipbop-4x3-gear4-test',
    title: 'Apple BipBop 4x3 Gear 4 HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear4/prog_index.m3u8',
    aspectRatio: 4 / 3,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'shaka-angel-one-test',
    title: 'Shaka Angel One HLS',
    sourceName: 'Shaka Player Demo Assets',
    sourcePage: 'https://shaka-player-demo.appspot.com/demo/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'shaka-bbb-dark-truths-test',
    title: 'Shaka Big Buck Bunny Dark Truths HLS',
    sourceName: 'Shaka Player Demo Assets',
    sourcePage: 'https://shaka-player-demo.appspot.com/demo/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'akamai-live-hls-test',
    title: 'Akamai Live HLS Test',
    sourceName: 'Akamai Test Stream',
    sourcePage: 'https://cph-p2p-msl.akamaized.net/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'unstable-source-test',
    title: 'JW Platform VOD HLS',
    sourceName: 'JW Player',
    sourcePage: 'https://developer.jwplayer.com/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl: 'https://content.jwplatform.com/manifests/vM7nH0Kl.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'slow-source-test',
    title: 'Unified Streaming Tears Slow HLS',
    sourceName: 'Unified Streaming',
    sourcePage:
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/',
    licenseNote:
        'Public HLS fixture for slow-source/bad-network testing and development; remote URL only.',
    videoUrl:
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'mux-arte-china-test',
    title: 'Mux ARTE China HLS',
    sourceName: 'Mux Test Streams',
    sourcePage: 'https://test-streams.mux.dev/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl: 'https://test-streams.mux.dev/test_001/stream.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'mux-pts-shift-test',
    title: 'Mux PTS Shift HLS',
    sourceName: 'Mux Test Streams',
    sourcePage: 'https://test-streams.mux.dev/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl: 'https://test-streams.mux.dev/pts_shift/master.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'mux-ad-discontinuity-test',
    title: 'Mux DAI Discontinuity HLS',
    sourceName: 'Mux Test Streams',
    sourcePage: 'https://test-streams.mux.dev/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://test-streams.mux.dev/dai-discontinuity-deltatre/manifest.m3u8',
    aspectRatio: 16 / 9,
  ),
  MockPlayerVideoAsset(
    sourceLabel: 'mux-issue666-test',
    title: 'Mux hls.js Issue 666 HLS',
    sourceName: 'Mux Test Streams',
    sourcePage: 'https://test-streams.mux.dev/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://test-streams.mux.dev/issue666/playlists/cisq0gim60007xzvi505emlxx.m3u8',
    aspectRatio: 16 / 9,
  ),
];

final defaultMockPlayerVideoAssets = [
  mockPlayerVideoAssets[0],
  mockPlayerVideoAssets[1],
  mockPlayerVideoAssets[2],
];

/// 播放内容 mock 仓库。
///
/// mock 内容使用稳定公开 HLS fixture，便于播放器链路测试。这里不要引入本地视频资源，
/// 否则 HLS preload/proxy/source resolve 的边界会被绕开。
class MockPlayerContentRepository implements PlayerContentRepository {
  const MockPlayerContentRepository();

  static const _networkDelay = Duration(milliseconds: 180);

  @override
  Future<PlayerContent> getPlayerContent({required String dramaId}) async {
    final profile = _profileFor(dramaId);

    return Future<PlayerContent>.delayed(
      _networkDelay,
      () => PlayerContent(
        id: dramaId,
        title: profile.title,
        playTitle: profile.playTitle,
        synopsis: profile.synopsis,
        viewCountLabel: profile.viewCountLabel,
        likeCountLabel: profile.likeCountLabel,
        backgroundAssetPath: 'assets/images/player/player_background.png',
        posterAssetPath: profile.posterAssetPath,
        episodes: List<PlayerEpisode>.generate(50, (index) {
          final number = index + 1;
          final videoAsset =
              defaultMockPlayerVideoAssets[index %
                  defaultMockPlayerVideoAssets.length];
          final unlockType = _unlockTypeForEpisode(number);
          return PlayerEpisode(
            id: 'ep-$number',
            number: number,
            isLocked: unlockType != EpisodeUnlockType.free,
            unlockType: unlockType,
            requiredCoins: _requiredCoinsForEpisode(number),
            videoUrl: videoAsset.videoUrl,
            videoAspectRatio: videoAsset.aspectRatio,
            duration: _durationForEpisode(number),
            isAvailable: number != 9,
          );
        }),
        recommendations: const [
          PlayerRecommendation(
            id: 'fallin-love',
            title: 'Fallin Love With Ex’s Uncle',
            subtitle: 'Young Adult',
            coverAssetPath: 'assets/images/player/recommend_1.png',
          ),
          PlayerRecommendation(
            id: 'wolf-queen',
            title: 'Wolf Queen Rises',
            subtitle: 'Young Adult',
            coverAssetPath: 'assets/images/player/recommend_2.png',
          ),
          PlayerRecommendation(
            id: 'paper-marriage',
            title: 'Fake Dating My Rich Nemesis',
            subtitle: 'Young Adult',
            coverAssetPath: 'assets/images/player/recommend_3.png',
          ),
          PlayerRecommendation(
            id: 'heartbroken-heir',
            title: 'Papei Marriage Heart’s Surprise',
            subtitle: 'Young Adult',
            coverAssetPath: 'assets/images/player/recommend_4.png',
          ),
          PlayerRecommendation(
            id: 'billionaire',
            title: 'Heaitbiaken or Heart-Stopping',
            subtitle: 'Young Adult',
            coverAssetPath: 'assets/images/player/recommend_1.png',
          ),
          PlayerRecommendation(
            id: 'boss-cleaner',
            title: 'Wolf Queen Rises',
            subtitle: 'Young Adult',
            coverAssetPath: 'assets/images/player/recommend_3.png',
          ),
        ],
      ),
    );
  }

  _MockPlayerContentProfile _profileFor(String dramaId) {
    final normalizedId = dramaId.replaceFirst(RegExp(r'-\d+$'), '');
    return _profiles[normalizedId] ?? _profiles['found-you']!;
  }
}

EpisodeUnlockType _unlockTypeForEpisode(int number) {
  if (number <= 3) {
    return EpisodeUnlockType.free;
  }
  if (number == 7) {
    return EpisodeUnlockType.membership;
  }
  return EpisodeUnlockType.coins;
}

Duration _durationForEpisode(int number) {
  return switch (number) {
    1 => const Duration(seconds: 105),
    2 => const Duration(seconds: 90),
    3 => const Duration(seconds: 95),
    _ => const Duration(seconds: 100),
  };
}

int _requiredCoinsForEpisode(int number) {
  // 默认 mock 账号有 4000 金币。这里保留 EP.04 低价用于验证“小解锁弹窗”，
  // 后续金币集设置成高价，用于直接验证“余额不足 -> 充值抽屉”链路。
  return switch (number) {
    4 => 60,
    5 => 6000,
    6 => 8000,
    _ => 10000,
  };
}

/// mock 视频资源描述。
///
/// 这里记录远端 HLS URL 和比例等播放器测试数据，不代表生产内容模型。
class MockPlayerVideoAsset {
  const MockPlayerVideoAsset({
    required this.sourceLabel,
    required this.title,
    required this.sourceName,
    required this.sourcePage,
    required this.licenseNote,
    required this.videoUrl,
    required this.aspectRatio,
  });

  final String sourceLabel;
  final String title;
  final String sourceName;
  final String sourcePage;
  final String licenseNote;
  final String videoUrl;
  final double aspectRatio;
}

const _profiles = {
  'found-you': _MockPlayerContentProfile(
    title: 'Reborn: The Cure',
    playTitle: 'My Secret Deal With The Playboy',
    synopsis:
        'Emily Carter is a renowned surgeon and the heir to the immensely wealthy Carter family.',
    viewCountLabel: '16.6M Views',
    likeCountLabel: '43.2K',
    posterAssetPath: 'assets/images/player/recommend_1.png',
  ),
  'heart-thief': _MockPlayerContentProfile(
    title: 'Heart Thief',
    playTitle: 'Found You, Heart Thief',
    synopsis:
        'A surgeon who no longer believes in love meets the one person who can expose the secret she has protected for years.',
    viewCountLabel: '18.2M Views',
    likeCountLabel: '51.8K',
    posterAssetPath: 'assets/images/player/recommend_2.png',
  ),
  'reborn-love': _MockPlayerContentProfile(
    title: 'Second Chance Vow',
    playTitle: 'Love After Rebirth',
    synopsis:
        'After waking up before the night everything fell apart, Mira decides to rewrite her marriage and reclaim her future.',
    viewCountLabel: '12.4M Views',
    likeCountLabel: '39.6K',
    posterAssetPath: 'assets/images/player/recommend_3.png',
  ),
  'secret-vow': _MockPlayerContentProfile(
    title: 'Secret Vow',
    playTitle: 'The Heiress Returns',
    synopsis:
        'A hidden heiress returns under a new identity, but every step toward revenge pulls her closer to an impossible romance.',
    viewCountLabel: '21.9M Views',
    likeCountLabel: '62.1K',
    posterAssetPath: 'assets/images/player/recommend_4.png',
  ),
  'asian-reunion': _MockPlayerContentProfile(
    title: 'Reunion Contract',
    playTitle: 'Married Again at Dawn',
    synopsis:
        'A contract marriage becomes a second chance when two former lovers are forced to protect the same family secret.',
    viewCountLabel: '9.7M Views',
    likeCountLabel: '28.4K',
    posterAssetPath: 'assets/images/player/recommend_1.png',
  ),
};

class _MockPlayerContentProfile {
  const _MockPlayerContentProfile({
    required this.title,
    required this.playTitle,
    required this.synopsis,
    required this.viewCountLabel,
    required this.likeCountLabel,
    required this.posterAssetPath,
  });

  final String title;
  final String playTitle;
  final String synopsis;
  final String viewCountLabel;
  final String likeCountLabel;
  final String posterAssetPath;
}
