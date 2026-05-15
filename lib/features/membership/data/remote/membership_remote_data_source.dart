import '../../../../core/network/api_client.dart';
import '../dto/membership_data_dto.dart';
import '../dto/membership_product_dto.dart';
import '../dto/membership_status_dto.dart';

/// 会员远程数据源骨架。
///
/// 商品列表假设可未登录查看；会员状态是登录后权益数据，必须 required。
class MembershipRemoteDataSource {
  const MembershipRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MembershipDataDto> getMembershipData({
    required String platform,
    required String locale,
  }) {
    return _apiClient.get<MembershipDataDto>(
      '/membership/products',
      queryParameters: {'platform': platform, 'locale': locale},
      authPolicy: ApiAuthPolicy.none,
      decoder: MembershipDataDto.fromJson,
    );
  }

  Future<List<MembershipProductDto>> listProducts({
    required String platform,
    required String locale,
  }) {
    return _apiClient.get<List<MembershipProductDto>>(
      '/membership/products',
      queryParameters: {'platform': platform, 'locale': locale},
      authPolicy: ApiAuthPolicy.none,
      decoder: (data) {
        final map = data is Map<String, Object?>
            ? data
            : const <String, Object?>{};
        final rawItems = map['products'] ?? data;
        if (rawItems is List) {
          return rawItems
              .map(MembershipProductDto.fromJson)
              .toList(growable: false);
        }
        return const <MembershipProductDto>[];
      },
    );
  }

  Future<MembershipStatusDto> getStatus() {
    return _apiClient.get<MembershipStatusDto>(
      '/membership/status',
      authPolicy: ApiAuthPolicy.required,
      decoder: MembershipStatusDto.fromJson,
    );
  }
}
