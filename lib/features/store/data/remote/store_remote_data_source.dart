import '../../../../core/network/api_client.dart';
import '../dto/order_create_request_dto.dart';
import '../dto/order_dto.dart';
import '../dto/store_recharge_data_dto.dart';

/// 充值商店远程数据源。
///
/// 商品列表接口：GET /api/payment/recharge/page
/// 创建订单属于登录后动作，必须 required。
class StoreRemoteDataSource {
  const StoreRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 获取充值页面数据
  /// 
  /// 对应后端 API：GET /api/payment/recharge/page
  Future<StoreRechargeDataDto> fetchRechargePage() {
    return _apiClient.get<StoreRechargeDataDto>(
      '/api/payment/recharge/page',
      authPolicy: ApiAuthPolicy.required,
      decoder: StoreRechargeDataDto.fromJson,
    );
  }

  Future<OrderDto> createOrder(OrderCreateRequestDto request) {
    return _apiClient.post<OrderDto>(
      '/orders',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: OrderDto.fromJson,
    );
  }
}
