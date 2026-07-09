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

  Future<List<PopupExitRecommendation>> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  });
}
