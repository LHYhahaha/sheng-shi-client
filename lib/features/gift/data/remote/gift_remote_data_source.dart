import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../../domain/gift_claim_data.dart';
import '../../domain/gift_link_data.dart';

class GiftRemoteDataSource {
  const GiftRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<GiftLinkData> getVipGiftLink() =>
      _getGiftLink('/api/user/gift/vip-link');

  Future<GiftLinkData> getDramaGiftLink({required int dramaId}) => _getGiftLink(
    '/api/user/gift/drama-link',
    queryParameters: {'dramaId': dramaId},
  );

  Future<GiftClaimData> claimGift({required String shareCode}) {
    return _apiClient.post<GiftClaimData>(
      '/api/user/gifts/claim',
      data: {'shareCode': shareCode},
      authPolicy: ApiAuthPolicy.required,
      decoder: GiftClaimDataDto.fromJson,
    );
  }

  Future<GiftLinkData> _getGiftLink(
    String path, {
    Map<String, Object?>? queryParameters,
  }) {
    return _apiClient.get<GiftLinkData>(
      path,
      queryParameters: queryParameters,
      authPolicy: ApiAuthPolicy.required,
      decoder: GiftLinkDataDto.fromJson,
    );
  }
}

class GiftClaimDataDto {
  static GiftClaimData fromJson(Object? json) {
    const dtoName = 'GiftClaimDataDto';
    final map = JsonFieldParser.requireMap(json, dtoName: dtoName);
    return GiftClaimData(
      benefitDays: JsonFieldParser.requireInt(
        map,
        'benefitDays',
        dtoName: dtoName,
      ),
      dramaId: JsonFieldParser.requireString(map, 'dramaId', dtoName: dtoName),
      giftType: JsonFieldParser.requireInt(map, 'giftType', dtoName: dtoName),
      isAvailable: JsonFieldParser.requireBool(
        map,
        'isAvailable',
        dtoName: dtoName,
      ),
      reason: JsonFieldParser.requireString(map, 'reason', dtoName: dtoName),
      reasonCode: JsonFieldParser.requireInt(
        map,
        'reasonCode',
        dtoName: dtoName,
      ),
      shareCode: JsonFieldParser.requireString(
        map,
        'shareCode',
        dtoName: dtoName,
      ),
    );
  }
}

class GiftLinkDataDto {
  static GiftLinkData fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return GiftLinkData(
      available: _bool(map['available']),
      benefitDays: _int(map['benefitDays']),
      reGrantAt: _string(map['reGrantAt']),
      remainCount: _int(map['remainCount']),
      shareCode: _string(map['shareCode']),
      shareUrl: _string(map['shareUrl']),
      totalCount: _int(map['totalCount']),
      usedCount: _int(map['usedCount']),
      visible: _bool(map['visible']),
    );
  }
}

bool _bool(Object? value) => value is bool ? value : value == 1 || value == '1';
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _string(Object? value) => value is String ? value : '';
