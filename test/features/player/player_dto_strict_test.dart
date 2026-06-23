import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/player/data/dto/playback_source_dto.dart';
import 'package:drama_client/features/player/data/mapper/playback_source_mapper.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourceMapper = PlaybackSourceMapper();

  test('denied playback source does not map to playable source', () {
    final item = _feedItem();
    final expiresAt = DateTime.now().add(const Duration(hours: 1));

    expect(
      () => sourceMapper.mapSource(
        PlaybackSourceDto(
          episodeId: 'ep-1',
          sourceId: 'blocked',
          hlsUrl: 'https://cdn.example.com/a.m3u8',
          backupHlsUrls: const [],
          expiresAt: expiresAt,
          durationMs: null,
          width: null,
          height: null,
          aspectRatio: null,
          codec: null,
          cachePolicy: const {},
          preloadPolicy: const {},
          subtitleTracks: const [],
          previewSpriteUrl: null,
          previewVttUrl: null,
          isAvailable: false,
          accessStatus: 'denied',
          reasonCode: 'ENTITLEMENT_REQUIRED',
        ),
        item: item,
        status: PlaybackSourceStatus.resolved,
      ),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('expired playback source throws', () {
    final item = _feedItem();

    expect(
      () => sourceMapper.mapSource(
        PlaybackSourceDto(
          episodeId: 'ep-1',
          sourceId: 'expired',
          hlsUrl: 'https://cdn.example.com/expired.m3u8',
          backupHlsUrls: const [],
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          durationMs: null,
          width: null,
          height: null,
          aspectRatio: null,
          codec: null,
          cachePolicy: const {},
          preloadPolicy: const {},
          subtitleTracks: const [],
          previewSpriteUrl: null,
          previewVttUrl: null,
          isAvailable: true,
        ),
        item: item,
        status: PlaybackSourceStatus.resolved,
      ),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('same HLS url different sourceId yields different cache keys', () {
    final item = _feedItem();
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    final url = 'https://cdn.example.com/shared.m3u8';

    final sourceA = sourceMapper.mapSource(
      PlaybackSourceDto(
        episodeId: 'ep-1',
        sourceId: 'source-a',
        hlsUrl: url,
        backupHlsUrls: const [],
        expiresAt: expiresAt,
        durationMs: null,
        width: null,
        height: null,
        aspectRatio: null,
        codec: null,
        cachePolicy: const {},
        preloadPolicy: const {},
        subtitleTracks: const [],
        previewSpriteUrl: null,
        previewVttUrl: null,
        isAvailable: true,
      ),
      item: item,
      status: PlaybackSourceStatus.resolved,
    );
    final sourceB = sourceMapper.mapSource(
      PlaybackSourceDto(
        episodeId: 'ep-1',
        sourceId: 'source-b',
        hlsUrl: url,
        backupHlsUrls: const [],
        expiresAt: expiresAt,
        durationMs: null,
        width: null,
        height: null,
        aspectRatio: null,
        codec: null,
        cachePolicy: const {},
        preloadPolicy: const {},
        subtitleTracks: const [],
        previewSpriteUrl: null,
        previewVttUrl: null,
        isAvailable: true,
      ),
      item: item,
      status: PlaybackSourceStatus.resolved,
    );

    expect(sourceA.cacheKey, isNot(sourceB.cacheKey));
  });
}

PlayerFeedItem _feedItem() {
  final content = PlayerContent(
    id: 'found-you',
    title: 'Found You',
    playTitle: 'Found You',
    synopsis: 'Synopsis',
    viewCountLabel: '1M',
    likeCountLabel: '1K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: const [],
    recommendations: const [],
    episodeTotal: 0,
  );
  final episode = PlayerEpisode(
    id: 'ep-1',
    number: 1,
    isLocked: false,
    videoAspectRatio: 16 / 9,
  );
  return PlayerFeedItem(
    id: 'single:found-you:ep-1',
    mode: PlayerFeedMode.singleDrama,
    content: content,
    episode: episode,
  );
}
