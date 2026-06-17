import '../../../../core/network/json_field_parser.dart';

/// 金币解锁剧集远程 DTO。
///
/// 接收 /api/payment/episode/unlock API 返回的数据格式。
class PlayerEpisodeUnlockDto {
  const PlayerEpisodeUnlockDto({
    required this.autoUnlock,
    required this.bonusCoin,
    required this.coin,
    required this.costCoin,
    required this.dramaId,
    required this.episodeId,
    required this.success,
    required this.userId,
    this.sourceUrl,
  });

  final bool autoUnlock;
  final int bonusCoin;
  final int coin;
  final int costCoin;
  final int dramaId;
  final int episodeId;
  final bool success;
  final int userId;
  final String? sourceUrl;

  factory PlayerEpisodeUnlockDto.fromJson(Map<String, Object?> json) {
    return PlayerEpisodeUnlockDto(
      autoUnlock: JsonFieldParser.optionalBool(json, 'autoUnlock') ?? false,
      bonusCoin: JsonFieldParser.optionalInt(json, 'bonusCoin') ?? 0,
      coin: JsonFieldParser.optionalInt(json, 'coin') ?? 0,
      costCoin: JsonFieldParser.optionalInt(json, 'costCoin') ?? 0,
      dramaId: JsonFieldParser.optionalInt(json, 'dramaId') ?? 0,
      episodeId: JsonFieldParser.optionalInt(json, 'episodeId') ?? 0,
      success: JsonFieldParser.optionalBool(json, 'success') ?? false,
      userId: JsonFieldParser.optionalInt(json, 'userId') ?? 0,
      sourceUrl: JsonFieldParser.optionalString(json, 'sourceUrl'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'autoUnlock': autoUnlock,
      'bonusCoin': bonusCoin,
      'coin': coin,
      'costCoin': costCoin,
      'dramaId': dramaId,
      'episodeId': episodeId,
      'success': success,
      'userId': userId,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
    };
  }
}
