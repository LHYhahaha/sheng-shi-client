import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/features/drama/data/dto/drama_category_dto.dart';
import 'package:drama_client/features/drama/data/dto/drama_dto.dart';
import 'package:drama_client/features/drama/data/dto/drama_feed_page_dto.dart';
import 'package:drama_client/features/drama/data/mapper/drama_mapper.dart';
import 'package:drama_client/features/drama/domain/drama.dart';

void main() {
  const mapper = DramaMapper();

  test('category dto maps to domain', () {
    final category = mapper.mapCategory(
      const DramaCategoryDto(id: 'popular', title: 'Popular', sortOrder: 1),
    );

    expect(category.id, 'popular');
    expect(category.title, 'Popular');
  });

  test('drama dto maps remote fields to home drama domain', () {
    final drama = mapper.mapDrama(
      const DramaDto(
        dramaId: 'found-you',
        title: 'Found You',
        description: 'Remote description',
        coverUrl: 'https://cdn.example.com/found-you.jpg',
        posterUrl: 'https://cdn.example.com/found-you-poster.jpg',
        viewCount: 84100000,
        viewCountLabel: '84.1 M',
        episodeCount: 52,
        tags: ['Rebirth'],
        badges: ['exclusive'],
        categoryIds: ['popular', 'asian'],
        coverAspectRatio: 0.75,
      ),
    );

    expect(drama.id, 'found-you');
    expect(drama.title, 'Found You');
    expect(drama.coverAssetPath, Drama.fallbackCoverAssetPath);
    expect(drama.coverResource.isNetwork, isTrue);
    expect(drama.coverResource.value, 'https://cdn.example.com/found-you.jpg');
    expect(drama.coverResource.aspectRatio, 0.75);
    expect(drama.viewCountLabel, '84.1 M');
    expect(drama.episodeCount, 52);
    expect(drama.categoryId, 'popular');
    expect(drama.tags, ['Rebirth']);
    expect(drama.coverAspectRatio, 0.75);
    expect(drama.isExclusive, isTrue);
  });

  test('drama dto falls back optional fields safely', () {
    final drama = mapper.mapDrama(
      const DramaDto(
        dramaId: 'minimal',
        title: 'Minimal',
        description: null,
        coverUrl: null,
        posterUrl: 'https://cdn.example.com/poster.jpg',
        viewCount: 1200,
        viewCountLabel: null,
        episodeCount: 0,
        tags: [],
        badges: [],
        categoryIds: [],
        coverAspectRatio: null,
      ),
    );

    expect(drama.coverAssetPath, Drama.fallbackCoverAssetPath);
    expect(drama.coverResource.isNetwork, isTrue);
    expect(drama.coverResource.value, 'https://cdn.example.com/poster.jpg');
    expect(drama.viewCountLabel, '1.2 K');
    expect(drama.categoryId, '');
    expect(drama.coverAspectRatio, closeTo(171 / 226, 0.0001));
    expect(drama.isExclusive, isFalse);
  });

  test('feed page dto maps items and nextPageToken', () {
    final page = mapper.mapFeedPage(
      const DramaFeedPageDto(
        items: [
          DramaDto(
            dramaId: 'found-you',
            title: 'Found You',
            description: null,
            coverUrl: 'https://cdn.example.com/found-you.jpg',
            posterUrl: null,
            viewCount: null,
            viewCountLabel: '84.1 M',
            episodeCount: 52,
            tags: ['Rebirth'],
            badges: [],
            categoryIds: ['popular'],
            coverAspectRatio: 0.75,
          ),
        ],
        nextPageToken: 'next-token',
      ),
    );

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'found-you');
    expect(page.nextPageToken, 'next-token');
  });

  test('missing cover and poster falls back to asset resource', () {
    final drama = mapper.mapDrama(
      const DramaDto(
        dramaId: 'no-cover',
        title: 'No Cover',
        description: null,
        coverUrl: null,
        posterUrl: null,
        viewCount: null,
        viewCountLabel: null,
        episodeCount: 1,
        tags: [],
        badges: [],
        categoryIds: ['popular'],
        coverAspectRatio: 0.8,
      ),
    );

    expect(drama.coverResource.isAsset, isTrue);
    expect(drama.coverResource.value, Drama.fallbackCoverAssetPath);
    expect(drama.coverResource.aspectRatio, 0.8);
  });

  test('mock drama constructor creates asset coverResource by default', () {
    final drama = Drama(
      id: 'mock',
      title: 'Mock',
      coverAssetPath: Drama.fallbackCoverAssetPath,
      viewCountLabel: '1 M',
      episodeCount: 12,
      categoryId: 'popular',
      tags: [],
      coverAspectRatio: 0.75,
    );

    expect(drama.coverResource.isAsset, isTrue);
    expect(drama.coverResource.value, Drama.fallbackCoverAssetPath);
    expect(drama.coverResource.aspectRatio, 0.75);
  });

  test('dto fromJson accepts missing optional fields', () {
    final dto = DramaDto.fromJson({
      'dramaId': 'remote-drama',
      'title': 'Remote Drama',
      'episodeCount': 12,
    });

    expect(dto.dramaId, 'remote-drama');
    expect(dto.title, 'Remote Drama');
    expect(dto.coverUrl, isNull);
    expect(dto.tags, isEmpty);
    expect(dto.badges, isEmpty);
    expect(dto.categoryIds, isEmpty);
  });
}
