import '../domain/membership_plan.dart';
import '../domain/membership_repository.dart';
import 'mapper/membership_mapper.dart';
import 'remote/membership_remote_data_source.dart';

class RemoteMembershipRepository implements MembershipRepository {
  const RemoteMembershipRepository({
    required MembershipRemoteDataSource remoteDataSource,
    MembershipMapper mapper = const MembershipMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final MembershipRemoteDataSource _remoteDataSource;
  final MembershipMapper _mapper;

  @override
  Future<MembershipData> fetchMembership({required int userId}) async {
    final dto = await _remoteDataSource.getMembershipData(userId: userId);
    return _mapper.mapData(dto);
  }
}
