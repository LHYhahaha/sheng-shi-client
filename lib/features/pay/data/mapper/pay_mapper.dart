import '../../domain/payment_order.dart';
import '../dto/payment_order_dto.dart';

/// 支付相关 DTO 到 Domain 的映射器
class PayMapper {
  const PayMapper();

  /// 将 PaymentOrderDto 映射为 PaymentOrder 领域模型
  PaymentOrder mapPaymentOrder(PaymentOrderDto dto) {
    return dto.toDomain();
  }
}
