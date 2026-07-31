import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/payment_purchase_coordinator.dart';
import 'pay_repository_provider.dart';

final paymentPurchaseCoordinatorProvider = Provider<PaymentPurchaseCoordinator>(
  (ref) => PaymentPurchaseCoordinator(
    payRepository: ref.watch(payRepositoryProvider),
  ),
);
