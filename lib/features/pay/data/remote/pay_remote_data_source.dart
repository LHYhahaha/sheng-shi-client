import 'package:drama_client/core/network/api_client.dart';
import '../dto/payment_order_create_request_dto.dart';
import '../dto/payment_order_dto.dart';
import '../dto/payment_order_verify_request_dto.dart';
import '../dto/payment_order_verify_response_dto.dart';

/// 支付远程数据源
///
/// 处理支付订单创建、验证等网络请求
class PayRemoteDataSource {
  const PayRemoteDataSource({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 创建支付订单（通用接口）
  ///
  /// 所有下单都经过这个接口，支持金币商品和会员商品
  Future<PaymentOrderDto> createPaymentOrder(PaymentOrderCreateRequestDto request) {
    return _apiClient.post<PaymentOrderDto>(
      '/api/payment/order/create',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: PaymentOrderDto.fromJson,
    );
  }

  /// 验证谷歌支付订单（通用接口）
  ///
  /// 支付成功后，将谷歌返回的凭证信息发送到服务端验证
  Future<PaymentOrderVerifyResponseDto> verifyGooglePayment(
    PaymentOrderVerifyRequestDto request,
  ) {
    return _apiClient.post<PaymentOrderVerifyResponseDto>(
      '/api/payment/google/verify',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: PaymentOrderVerifyResponseDto.fromJson,
    );
  }
}
