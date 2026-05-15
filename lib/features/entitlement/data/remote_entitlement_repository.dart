import '../domain/entitlement_repository.dart';
import '../domain/user_entitlement_state.dart';
import 'dto/unlock_episode_request_dto.dart';
import 'mapper/entitlement_mapper.dart';
import 'remote/entitlement_remote_data_source.dart';

/// Entitlement 远程 repository 骨架。
///
/// grantMock* 在远程实现中不会本地发放权益，只刷新服务端权益快照；真实购买成功仍必须
/// 经过订单/验单/权益接口确认。
class RemoteEntitlementRepository implements EntitlementRepository {
  const RemoteEntitlementRepository({
    required EntitlementRemoteDataSource remoteDataSource,
    EntitlementMapper mapper = const EntitlementMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final EntitlementRemoteDataSource _remoteDataSource;
  final EntitlementMapper _mapper;

  @override
  Future<UserEntitlementState> fetchState() async {
    final dto = await _remoteDataSource.fetchEntitlements();
    return _mapper.mapState(dto);
  }

  @override
  Future<UserEntitlementState> setAutoUnlockEnabled(bool enabled) async {
    final dto = await _remoteDataSource.setAutoUnlockEnabled(enabled);
    return _mapper.mapState(dto);
  }

  @override
  Future<UserEntitlementState> grantMockMembership({required String source}) {
    return fetchState();
  }

  @override
  Future<UserEntitlementState> grantMockCoins({
    required int amount,
    required String source,
  }) {
    return fetchState();
  }

  @override
  Future<UserEntitlementState> unlockEpisodeWithCoins({
    required String dramaId,
    required String episodeId,
    required int price,
    required String operationId,
  }) async {
    final response = await _remoteDataSource.unlockEpisode(
      UnlockEpisodeRequestDto(
        dramaId: dramaId,
        episodeId: episodeId,
        requiredCoins: price,
        operationId: operationId,
      ),
    );
    final state = response.state;
    if (state != null) {
      return _mapper.mapState(state);
    }
    return fetchState();
  }
}
