import 'package:dio/dio.dart';

import '../domain/popup.dart';
import 'popup_repository.dart';
import 'remote/popup_remote_data_source.dart';

class RemotePopupRepository implements PopupRepository {
  const RemotePopupRepository({required PopupRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final PopupRemoteDataSource _remoteDataSource;

  @override
  Future<List<PopupConfig>> fetchPopups({
    required PopupPlacementCode placement,
  }) async {
    final dtos = await _remoteDataSource.fetchPopups(
      placementCode: placement.apiValue,
    );
    return dtos.map((dto) => dto.toDomain()).toList(growable: false);
  }

  @override
  Future<void> reportPopupEvent({
    required int popupId,
    required PopupEventType eventType,
  }) {
    return _remoteDataSource.reportPopupEvent(
      popupId: popupId,
      eventType: eventType.apiValue,
    );
  }

  @override
  Future<PopupExitRecommendationSet> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  }) async {
    final dto = await _remoteDataSource.fetchDetailExitPopup(
      dramaId: dramaId,
      cancelToken: cancelToken,
    );
    return PopupExitRecommendationSet(
      popupId: dto.popupId,
      recommendations: dto.dramas
          .map((drama) => drama.toDomain())
          .toList(growable: false),
    );
  }
}
