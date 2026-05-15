import '../domain/wallet_record.dart';
import '../domain/wallet_repository.dart';
import 'mapper/wallet_mapper.dart';
import 'remote/wallet_remote_data_source.dart';

/// 钱包远程 repository 骨架。
///
/// 当前只实现现有 WalletRepository 所需的聚合拉取；流水分页、奖励领取和设置写入已在
/// data source 暴露，后续页面状态机接真实 API 时再逐步接入。
class RemoteWalletRepository implements WalletRepository {
  const RemoteWalletRepository({
    required WalletRemoteDataSource remoteDataSource,
    WalletMapper mapper = const WalletMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final WalletRemoteDataSource _remoteDataSource;
  final WalletMapper _mapper;

  @override
  Future<WalletData> fetchWallet() async {
    final dto = await _remoteDataSource.getWallet();
    return _mapper.mapWallet(dto);
  }
}
