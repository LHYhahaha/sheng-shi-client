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
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return UnlockEpisodeResponseDto(
      result: map['result'] is String ? map['result'] as String : 'success',
      state: map['state'] == null
          ? null
          : UserEntitlementStateDto.fromJson(map['state']),
      decision: map['decision'] == null
          ? null
          : EpisodeAccessDecisionDto.fromJson(map['decision']),
      reason: map['reason'] is String ? map['reason'] as String : null,
    );
  }
}
