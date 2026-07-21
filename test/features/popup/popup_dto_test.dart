import 'package:drama_client/features/popup/data/dto/popup_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses h5 open type from popup payload', () {
    final popup = PopupDto.fromJson(const {
      'id': 12,
      'content_mode': 1,
      'jump_type': 2,
      'h5_url': 'https://example.test/activity',
      'h5_open_type': 2,
    }).toDomain();

    expect(popup.h5Url, 'https://example.test/activity');
    expect(popup.h5OpenType, 2);
  });
}
