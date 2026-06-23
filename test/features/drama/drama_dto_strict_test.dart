import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/home/data/dto/drama_dto.dart';
import 'package:drama_client/features/home/data/mapper/home_mapper.dart';
import 'package:drama_client/features/home/domain/drama.dart';
import 'package:drama_client/shared/media/media_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = DramaMapper();

  test('missing drama id throws', () {
    expect(
      () => DramaDto.fromJson({'title': 'No Id'}),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('missing title uses display fallback in mapper', () {
    final drama = mapper.mapDrama(
      DramaDto.fromJson({'dramaId': 'drama-1', 'episodeCount': 1}),
    );

    expect(drama.title, 'Untitled');
  });

  test('invalid cover uses asset fallback without crash', () {
    final drama = mapper.mapDrama(
      DramaDto.fromJson({
        'dramaId': 'drama-1',
        'title': 'Drama',
        'coverUrl': '',
        'posterUrl': null,
        'episodeCount': 1,
      }),
    );

    expect(drama.coverResource.type, MediaResourceType.asset);
    expect(drama.coverResource.value, Drama.fallbackCoverAssetPath);
  });
}
