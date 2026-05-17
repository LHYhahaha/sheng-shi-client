import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/core/network/json_field_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonFieldParser', () {
    test('requireString missing or wrong type throws', () {
      expect(
        () => JsonFieldParser.requireString({}, 'id', dtoName: 'TestDto'),
        throwsA(
          isA<ApiMappingException>().having((e) => e.field, 'field', 'id'),
        ),
      );
      expect(
        () =>
            JsonFieldParser.requireString({'id': 1}, 'id', dtoName: 'TestDto'),
        throwsA(isA<ApiMappingException>()),
      );
    });

    test('requireInt missing or wrong type throws', () {
      expect(
        () => JsonFieldParser.requireInt({}, 'count', dtoName: 'TestDto'),
        throwsA(isA<ApiMappingException>()),
      );
    });

    test('parseUnlockType unknown throws', () {
      expect(
        () => JsonFieldParser.parseUnlockType({
          'unlockType': 'mystery',
        }, dtoName: 'TestDto'),
        throwsA(
          isA<ApiMappingException>().having(
            (e) => e.field,
            'field',
            'unlockType',
          ),
        ),
      );
    });

    test('optionalString returns null for missing display field', () {
      expect(JsonFieldParser.optionalString({}, 'title'), isNull);
      expect(
        JsonFieldParser.optionalString({'title': 'Hello'}, 'title'),
        'Hello',
      );
    });

    test('requireMap rejects non-object payload', () {
      expect(
        () => JsonFieldParser.requireMap([], dtoName: 'TestDto'),
        throwsA(isA<ApiMappingException>()),
      );
    });
  });
}
