import 'package:flutter/cupertino.dart';

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
  /// 返回：会员商品列表和当前会员状态
  Future<MembershipDataDto> getMembershipData() {
    debugPrint('[MembershipRemote] 开始请求会员数据');

    return _apiClient.get<MembershipDataDto>(
      '/api/payment/member/page',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        try {
          debugPrint('[MembershipRemote] decoder 收到数据: $data');
          final dto = MembershipDataDto.fromJson(data);
          debugPrint(
            '[MembershipRemote] decoder 成功: isMember=${dto.isMember}, products=${dto.memberProducts.length}',
          );
          return dto;
        } catch (e, stack) {
          debugPrint('[MembershipRemote] decoder 失败: $e');
          debugPrint('[MembershipRemote] decoder 堆栈: $stack');
          rethrow;
        }
      },
    );
  }
}
