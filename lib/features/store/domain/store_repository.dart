import 'store_package.dart';

abstract interface class StoreRepository {
  Future<StoreRechargeData> fetchRechargeData();
}
