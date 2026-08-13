import 'package:drama_client/features/search/data/dto/search_results_response_dto.dart';
import 'package:drama_client/features/search/data/mapper/search_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps drama watch progress from search results', () {
    final dto = SearchResultsResponseDto.fromJson({
      'keyword': 'love',
      'page': 1,
      'page_size': 20,
      'total': 1,
      'dramas': [
        {
          'id': 823,
          'sort': 1,
          'cover_url': 'cover.jpg',
          'title': 'handmade_vinegar_brewer_823',
          'summary': '',
          'tags_name': ['urban'],
          'category_names': ['selected'],
          'play_count': 10,
          'trailer_episode_num': 11,
          'is_vip_only': 0,
          'status': 1,
          'episode_total': 78,
          'watch_progress': {
            'watch_episode_id': 8604,
            'watch_episode_no': 1,
            'watch_second': 7,
            'duration_second': 78,
            'progress_percent': 8,
          },
        },
      ],
      'guess_like': [],
    });

    final drama = const SearchMapper().mapResults(dto).dramas.single;

    expect(drama.watchProgress?.episodeId, '8604');
    expect(drama.watchProgress?.episodeNo, 1);
    expect(drama.watchProgress?.watchSecond, 7);
    expect(drama.watchProgress?.durationSecond, 78);
  });
}
