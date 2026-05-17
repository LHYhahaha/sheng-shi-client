import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';

class EpisodeAccessDecisionDto {
  const EpisodeAccessDecisionDto({
    required this.type,
    required this.dramaId,
    required this.episodeId,
    required this.itemId,
    required this.unlockType,
    this.price,
    this.balance,
    this.reason,
    this.operationId,
  });

  final String type;
  final String dramaId;
  final String episodeId;
  final String itemId;
  final String unlockType;
  final int? price;
  final int? balance;
  final String? reason;
  final String? operationId;

  factory EpisodeAccessDecisionDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'EpisodeAccessDecisionDto',
    );
    const dtoName = 'EpisodeAccessDecisionDto';
    final unlockType = JsonFieldParser.parseUnlockType(map, dtoName: dtoName);
    final type = JsonFieldParser.parseDecisionType(map, dtoName: dtoName);
    final price = JsonFieldParser.optionalInt(map, 'price');
    if (type == 'showCoinUnlockDialog' && price == null) {
      throw ApiMappingException(
        dtoName: dtoName,
        field: 'price',
        reason: 'coin unlock decision requires price',
      );
    }

    return EpisodeAccessDecisionDto(
      type: type,
      dramaId: JsonFieldParser.requireString(map, 'dramaId', dtoName: dtoName),
      episodeId: JsonFieldParser.requireString(
        map,
        'episodeId',
        dtoName: dtoName,
      ),
      itemId: JsonFieldParser.requireString(map, 'itemId', dtoName: dtoName),
      unlockType: unlockType,
      price: price,
      balance: JsonFieldParser.optionalInt(map, 'balance'),
      reason: JsonFieldParser.optionalString(map, 'reason'),
      operationId: JsonFieldParser.optionalString(map, 'operationId'),
    );
  }
}
