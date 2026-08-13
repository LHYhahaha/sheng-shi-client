import 'package:drama_client/features/home/data/dto/home_response_dto.dart';
import 'package:drama_client/features/home/data/mapper/home_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps card favorite state and watch progress from home response', () {
    final dto = HomeResponseDto.fromJson({
      'id': 20,
      'name': 'Home',
      'status': 1,
      'tabs': [
        {
          'id': 3,
          'name': 'cartoon',
          'flag': 'cartoon',
          'sort': 1,
          'status': 1,
          'page': 1,
          'page_size': 3,
          'drama_total': 1,
          'dramas': [
            {
              'id': 1508,
              'sort': 1,
              'cover_url': 'https://example.com/cover.jpg',
              'title': 'Drama',
              'summary': '',
              'play_count': 1,
              'trailer_episode_num': 1,
              'is_vip_only': 0,
              'status': 1,
              'episode_total': 8,
              'is_favorited': 1,
              'watch_progress': {
                'watch_episode_id': 8519,
                'watch_episode_no': 2,
                'watch_second': 105,
                'progress_percent': 48,
                'duration_second': 217,
              },
            },
          ],
        },
      ],
    });

    final drama = const HomeMapper().mapHomeData(dto).tabs.single.dramas.single;

    expect(drama.isFavorited, isTrue);
    expect(drama.watchProgress?.episodeId, '8519');
    expect(drama.watchProgress?.episodeNo, 2);
    expect(drama.watchProgress?.positionSeconds, 105);
    expect(drama.watchProgress?.progressPercent, 48);
    expect(drama.watchProgress?.durationSeconds, 217);
  });
}
