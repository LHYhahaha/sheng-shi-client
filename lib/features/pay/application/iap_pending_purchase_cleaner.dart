import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/iap_purchase_service_provider.dart';

final iapPendingPurchaseCleanerProvider = Provider<IapPendingPurchaseCleaner>((
  ref,
) {
  return IapPendingPurchaseCleaner(ref);
});

class IapPendingPurchaseCleaner {
  const IapPendingPurchaseCleaner(this._ref);

  final Ref _ref;

  Future<void> cleanupBeforeCreateOrder({
    required String source,
    Set<String>? productIds,
  }) async {
    final iapService = _ref.read(iapPurchaseServiceProvider);
    if (iapService == null) {
      debugPrint(
        '[IapPendingCleanup] skip cleanup before create order, '
        'iap service unavailable, source=$source',
      );
      return;
    }

    final consumedCount = await iapService.restoreAndConsumePendingPurchases(
      source: source,
      productIds: productIds,
    );
    debugPrint(
      '[IapPendingCleanup] cleanup before create order finished, '
      'source=$source, consumedCount=$consumedCount',
    );
  }
}
