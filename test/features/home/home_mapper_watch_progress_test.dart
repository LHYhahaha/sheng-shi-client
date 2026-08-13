import 'package:drama_client/features/home/data/dto/home_response_dto.dart';
import 'package:drama_client/features/home/data/mapper/home_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps drama watch progress from home response', () {
    final dto = HomeResponseDto.fromJson({
      'id': 34,
      'name': 'home',
      'status': 1,
      'tabs': [
        {
          'id': 27,
          'name': 'selected',
          'flag': 'selected',
          'sort': 1,
          'status': 1,
          'page': 1,
          'page_size': 20,
          'drama_total': 1,
          'dramas': [
            {
              'id': 2527,
              'sort': 1,
              'cover_url': 'cover.jpg',
              'title': 'Love Blind Box',
              'summary': '',
              'play_count': 0,
              'trailer_episode_num': 10,
              'is_vip_only': 0,
              'status': 1,
              'episode_total': 70,
              'tags_name': ['romance'],
              'watch_progress': {
                'watch_episode_id': 51837,
                'watch_episode_no': 3,
                'watch_second': 35,
                'duration_second': 126,
                'progress_percent': 27,
              },
            },
          ],
        },
      ],
    });

    final drama = const HomeMapper().mapHomeData(dto).tabs.single.dramas.single;

    expect(drama.watchProgress?.episodeId, '51837');
    expect(drama.watchProgress?.episodeNo, 3);
    expect(drama.watchProgress?.watchSecond, 35);
    expect(drama.watchProgress?.durationSecond, 126);
  });
}
