import '../../domain/pay_repository.dart';
import '../../domain/payment_order.dart';
import '../../domain/payment_method_options.dart';
import '../dto/payment_order_create_request_dto.dart';
import '../dto/payment_order_options_request_dto.dart';
import '../dto/payment_order_verify_request_dto.dart';
import '../dto/payment_order_verify_response_dto.dart';
import '../remote/pay_remote_data_source.dart';

/// 远程支付仓库实现
class RemotePayRepository implements PayRepository {
  const RemotePayRepository({required PayRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final PayRemoteDataSource _remoteDataSource;

  @override
  Future<PaymentMethodOptions> getPaymentOrderOptions({
    required int osType,
    required int payScene,
    required int productId,
    required int productType,
    String? countryCode,
    int? dramaId,
    int? episodeId,
    int? episodeNo,
    String? scene,
  }) async {
    final request = PaymentOrderOptionsRequestDto(
      countryCode: countryCode,
      dramaId: dramaId,
      episodeId: episodeId,
      episodeNo: episodeNo,
      osType: osType,
      payScene: payScene,
      productId: productId,
      productType: productType,
      scene: scene,
    );
    return (await _remoteDataSource.getPaymentOrderOptions(request)).toDomain();
  }

  @override
  Future<PaymentOrder> createPaymentOrder({
    required int productId,
    required int productType,
    String? clientOrderNo,
    int? episodeId,
    int? payChannel,
    String? scene,
    int? shortId,
  }) async {
    final request = PaymentOrderCreateRequestDto(
      productId: productId,
      productType: productType,
      clientOrderNo: clientOrderNo,
      episodeId: episodeId,
      payChannel: payChannel,
      scene: scene,
      shortId: shortId,
    );

    final dto = await _remoteDataSource.createPaymentOrder(request);
    final order = dto.toDomain();
    return order.clientOrderNo == null || order.clientOrderNo!.isEmpty
        ? order.copyWith(clientOrderNo: request.clientOrderNo)
        : order;
  }

  @override
  Future<PaymentOrderVerifyResponseDto> verifyGooglePayment({
    required String orderNo,
    required String channelProductId,
    required String packageName,
    required int productType,
    required String purchaseToken,
    String? channelOrderId,
    String? rawReceipt,
  }) async {
    final request = PaymentOrderVerifyRequestDto(
      orderNo: orderNo,
      channelOrderId: channelOrderId,
      channelProductId: channelProductId,
      packageName: packageName,
      productType: productType,
      purchaseToken: purchaseToken,
      rawReceipt: rawReceipt,
    );

    return _remoteDataSource.verifyGooglePayment(request);
  }
}
