import 'package:dio/dio.dart';

import '../domain/popup.dart';

abstract class PopupRepository {
  Future<PopupConfig?> fetchPopup({required PopupPlacementCode placement});

  Future<List<PopupExitRecommendation>> fetchDetailExitRecommendations({
    required String dramaId,
    CancelToken? cancelToken,
  });
}
