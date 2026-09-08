import '../../../../core/network/json_field_parser.dart';
import '../../domain/drama_trial.dart';

/// 各短剧列表接口共用的可选限时试看配置。
class DramaTrialDto {
  const DramaTrialDto({
    required this.trialEnabled,
    required this.trialEpisodeNum,
    required this.trialDurationSec,
  });

  final int trialEnabled;
  final int trialEpisodeNum;
  final int trialDurationSec;

  factory DramaTrialDto.fromJson(Map<String, Object?> json) {
    return DramaTrialDto(
      trialEnabled: JsonFieldParser.optionalInt(json, 'trial_enabled') ?? 0,
      trialEpisodeNum:
          JsonFieldParser.optionalInt(json, 'trial_episode_num') ?? 0,
      trialDurationSec:
          JsonFieldParser.optionalInt(json, 'trial_duration_sec') ?? 0,
    );
  }

  DramaTrial toDomain() => DramaTrial(
    trialEnabled: trialEnabled == 1,
    trialEpisodeNum: trialEpisodeNum,
    trialDurationSec: trialDurationSec,
  );

  static DramaTrialDto? fromJsonOrNull(Object? value) {
    if (value is! Map) return null;
    return DramaTrialDto.fromJson(Map<String, Object?>.from(value));
  }
}
