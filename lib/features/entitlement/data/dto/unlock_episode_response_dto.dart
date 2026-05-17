import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';
import 'episode_access_decision_dto.dart';
import 'user_entitlement_state_dto.dart';

class UnlockEpisodeResponseDto {
  const UnlockEpisodeResponseDto({
    required this.result,
    this.state,
    this.decision,
    this.reason,
  });

  final String result;
  final UserEntitlementStateDto? state;
  final EpisodeAccessDecisionDto? decision;
  final String? reason;

  factory UnlockEpisodeResponseDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'UnlockEpisodeResponseDto',
    );
    const dtoName = 'UnlockEpisodeResponseDto';
    final result = map['result'];
    if (result is! String || result.isEmpty) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'result',
        reason: 'required unlock result',
      );
    }
    const allowed = {
      'success',
      'alreadyunlocked',
      'insufficientcoins',
      'membershiprequired',
      'unavailable',
      'failed',
    };
    if (!allowed.contains(result.toLowerCase())) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'result',
        reason: 'unknown unlock result',
      );
    }

    return UnlockEpisodeResponseDto(
      result: result,
      state: map['state'] == null
          ? null
          : UserEntitlementStateDto.fromJson(map['state']),
      decision: map['decision'] == null
          ? null
          : EpisodeAccessDecisionDto.fromJson(map['decision']),
      reason: JsonFieldParser.optionalString(map, 'reason'),
    );
  }
}
