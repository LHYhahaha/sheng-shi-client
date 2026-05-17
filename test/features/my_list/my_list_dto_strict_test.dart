import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/my_list/data/dto/favorite_item_dto.dart';
import 'package:drama_client/features/my_list/data/dto/play_history_item_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite missing dramaId throws', () {
    expect(
      () => FavoriteItemDto.fromJson({'title': 'Drama'}),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('history missing stable id throws', () {
    expect(
      () =>
          PlayHistoryItemDto.fromJson({'dramaId': 'drama-1', 'title': 'Drama'}),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('history accepts episodeId when historyId missing', () {
    final dto = PlayHistoryItemDto.fromJson({
      'dramaId': 'drama-1',
      'episodeId': 'ep-1',
      'title': 'Drama',
    });

    expect(dto.dramaId, 'drama-1');
    expect(dto.episodeId, 'ep-1');
  });
}
