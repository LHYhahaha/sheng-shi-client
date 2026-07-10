import 'package:drama_client/features/search/data/dto/search_ranking_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses play_count when search_count is missing', () {
    final dto = SearchRankingResponseDto.fromJson({
      'limit': 10,
      'dramas': [
        {'id': 1, 'sort': 1, 'title': 'Hot play', 'play_count': 1234},
      ],
    });

    expect(dto.dramas.single.searchCount, 1234);
  });

  test('keeps search_count ahead of play_count when both are present', () {
    final dto = SearchRankingResponseDto.fromJson({
      'limit': 10,
      'dramas': [
        {
          'id': 1,
          'sort': 1,
          'title': 'Hot search',
          'search_count': 88,
          'play_count': 1234,
        },
      ],
    });

    expect(dto.dramas.single.searchCount, 88);
  });
}
