import '../../../../core/network/api_client.dart';
import '../dto/membership_data_dto.dart';

/// 会员远程数据源。
///
/// 会员商品列表和会员状态来自同一接口，需要 token 认证。
class MembershipRemoteDataSource {
  const MembershipRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 获取会员页数据（包含商品列表和会员状态）。
  ///
  /// 接口：POST /api/payment/member/page
  /// 参数：{"userId": userId}
  /// 返回：会员商品列表和当前会员状态
  Future<MembershipDataDto> getMembershipData({required int userId}) {
    return _apiClient.get<MembershipDataDto>(
      '/api/payment/member/page',
      queryParameters: {'userId': userId},
      authPolicy: ApiAuthPolicy.required,
      decoder: MembershipDataDto.fromJson,
    );
  }
}
