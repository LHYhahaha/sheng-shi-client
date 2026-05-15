import '../../../../core/network/api_client.dart';
import '../dto/order_create_request_dto.dart';
import '../dto/order_dto.dart';
import '../dto/store_recharge_data_dto.dart';

/// 充值商店远程数据源骨架。
///
/// 商品列表当前假设可未登录查看，所以使用 none；创建订单属于登录后动作，必须 required。
class StoreRemoteDataSource {
  const StoreRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<StoreRechargeDataDto> listRechargeProducts({
    required String platform,
    required String locale,
  }) {
    return _apiClient.get<StoreRechargeDataDto>(
      '/store/recharge-products',
      queryParameters: {'platform': platform, 'locale': locale},
      authPolicy: ApiAuthPolicy.none,
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
