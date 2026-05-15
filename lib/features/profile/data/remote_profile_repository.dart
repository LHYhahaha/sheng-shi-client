import '../domain/profile_repository.dart';
import '../domain/profile_summary.dart';
import 'mapper/profile_mapper.dart';
import 'remote/profile_remote_data_source.dart';

class RemoteProfileRepository implements ProfileRepository {
  const RemoteProfileRepository({
    required ProfileRemoteDataSource remoteDataSource,
    ProfileMapper mapper = const ProfileMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final ProfileRemoteDataSource _remoteDataSource;
  final ProfileMapper _mapper;

  @override
  Future<ProfileSummary> fetchProfileSummary() async {
    final dto = await _remoteDataSource.getProfile();
    return _mapper.mapSummary(dto);
  }
}
