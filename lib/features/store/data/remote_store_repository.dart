import '../domain/store_package.dart';
import '../domain/store_repository.dart';
import 'mapper/store_mapper.dart';
import 'remote/store_remote_data_source.dart';

class RemoteStoreRepository implements StoreRepository {
  const RemoteStoreRepository({
    required StoreRemoteDataSource remoteDataSource,
    StoreMapper mapper = const StoreMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final StoreRemoteDataSource _remoteDataSource;
  final StoreMapper _mapper;

  @override
  Future<StoreRechargeData> fetchRechargeData() async {
    final dto = await _remoteDataSource.fetchRechargePage();
    return _mapper.mapRechargeData(dto);
  }
}
