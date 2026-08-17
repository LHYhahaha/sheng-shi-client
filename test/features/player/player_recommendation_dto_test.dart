import 'package:drama_client/features/player/data/dto/player_recommendation_dto.dart';
import 'package:drama_client/features/player/data/mapper/player_recommendation_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps root-array tag recommendation watch progress through mapping',
    () {
      final dto = PlayerRecommendationDto.fromJson(const <String, Object?>{
        'id': 799,
        'title': 'Recommended drama',
        'watch_progress': <String, Object?>{
          'watch_episode_id': 8519,
          'watch_episode_no': 12,
          'watch_second': 74,
          'progress_percent': 34,
          'duration_second': 217,
        },
      });

      final recommendation = const PlayerRecommendationMapper()
          .mapRecommendation(dto);

      expect(recommendation.watchProgress!.episodeId, '8519');
      expect(recommendation.watchProgress!.positionSeconds, 74);
    },
  );
}
