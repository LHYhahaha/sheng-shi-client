import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/home/data/dto/drama_category_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing category id throws', () {
    expect(
      () => DramaCategoryDto.fromJson({'title': 'Popular', 'sortOrder': 1}),
      throwsA(isA<ApiMappingException>()),
    );
  });
}
