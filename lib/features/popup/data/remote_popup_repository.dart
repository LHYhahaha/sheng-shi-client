import 'package:dio/dio.dart';

import '../domain/popup.dart';
import 'popup_repository.dart';
import 'remote/popup_remote_data_source.dart';

class RemotePopupRepository implements PopupRepository {
  const RemotePopupRepository({required PopupRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final PopupRemoteDataSource _remoteDataSource;

  @override
  Future<PopupConfig?> fetchPopup({
    required PopupPlacementCode placement,
  }) async {
    final dto = await _remoteDataSource.fetchPopup(
      placementCode: placement.apiValue,
    );
    return dto?.toDomain();
  }

  @override
  Future<List<PopupExitRecommendation>> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  }) async {
    final dto = await _remoteDataSource.fetchDetailExitPopup(
      dramaId: dramaId,
      cancelToken: cancelToken,
    );
    return dto.dramas.map((drama) => drama.toDomain()).toList(growable: false);
  }
}
