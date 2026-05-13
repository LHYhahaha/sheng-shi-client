import '../domain/player_content.dart';

class MockPlayerContentRepository implements PlayerContentRepository {
  const MockPlayerContentRepository();

  static const _networkDelay = Duration(milliseconds: 180);

  @override
  Future<PlayerContent> getPlayerContent({required String dramaId}) async {
    return Future<PlayerContent>.delayed(
      _networkDelay,
      () => PlayerContent(
        id: dramaId,
        title: 'Reborn: The Cure',
        playTitle: 'A Life That Shines Again',
        synopsis:
            'For seven years, Yun Seo-rin has given everything to her billionaire husband and their daughter. On her birthday, she discovers they are celebrating her husband’s half-sister instead.',
        viewCountLabel: '16.6M Views',
        likeCountLabel: '43.2K',
        backgroundAssetPath: 'assets/images/player/player_background.png',
        posterAssetPath: 'assets/images/player/recommend_1.png',
        episodes: List<PlayerEpisode>.generate(50, (index) {
          final number = index + 1;
          return PlayerEpisode(
            id: 'ep-$number',
            number: number,
            isLocked: number >= 11,
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
}
