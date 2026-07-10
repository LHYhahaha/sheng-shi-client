import 'package:dio/dio.dart';

import '../domain/popup.dart';

abstract class PopupRepository {
  Future<List<PopupConfig>> fetchPopups({
    required PopupPlacementCode placement,
  });

  Future<void> reportPopupEvent({
    required int popupId,
    required PopupEventType eventType,
  });

  Future<PopupExitRecommendationSet> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  });
}
