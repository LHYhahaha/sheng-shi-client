import '../domain/player_content.dart';

const mockPlayerVideoAssets = [
  MockPlayerVideoAsset(
    title: 'Tears of Steel HLS',
    sourceName: 'Unified Streaming',
    sourcePage:
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
  ),
  MockPlayerVideoAsset(
    title: 'BipBop Advanced TS HLS',
    sourceName: 'Apple Developer',
    sourcePage: 'https://developer.apple.com/streaming/examples/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl:
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
  ),
  MockPlayerVideoAsset(
    title: 'Mux x36xhzz HLS',
    sourceName: 'Mux Test Streams',
    sourcePage: 'https://test-streams.mux.dev/',
    licenseNote:
        'Public HLS fixture for testing and development; remote URL only.',
    videoUrl: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  ),
];

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
              mockPlayerVideoAssets[index % mockPlayerVideoAssets.length];
          return PlayerEpisode(
            id: 'ep-$number',
            number: number,
            isLocked: number >= 11,
            videoUrl: videoAsset.videoUrl,
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

class MockPlayerVideoAsset {
  const MockPlayerVideoAsset({
    required this.title,
    required this.sourceName,
    required this.sourcePage,
    required this.licenseNote,
    required this.videoUrl,
  });

  final String title;
  final String sourceName;
  final String sourcePage;
  final String licenseNote;
  final String videoUrl;
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
