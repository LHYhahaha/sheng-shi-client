import '../analytics/analytics_definition.dart';
import '../analytics/analytics_event.dart';
import '../analytics/analytics_service.dart';
import 'app_modal_request.dart';

/// 将全局弹窗的实际展示/关闭时机接入统一埋点。
///
/// 只有 request 声明了 [AppModalRequest.analyticsPopupShowParameters] 才会产生埋点；
/// 入队、展示失败或尚未展示就被取消的请求不会误报。
class AppModalAnalyticsTracker {
  AppModalAnalyticsTracker(this._analytics);

  final AnalyticsService _analytics;
  final Set<String> _shownRequestIds = <String>{};

  void onPresented(AppModalRequest request) {
    final parameters = request.analyticsPopupShowParameters;
    if (parameters == null || !_shownRequestIds.add(request.requestId)) {
      return;
    }
    _analytics.track(
      AnalyticsEvent(AnalyticsDefinitions.popupShow, parameters),
    );
  }

  void onClosed(AppModalRequest request) {
    if (!_shownRequestIds.remove(request.requestId)) {
      return;
    }
    final parameters = request.analyticsPopupShowParameters;
    final popupName = parameters?['popup_name'];
    if (popupName is! String || popupName.isEmpty || parameters == null) {
      return;
    }
    _analytics.track(
      AnalyticsEvent(AnalyticsDefinitions.popupClose, parameters),
    );
  }
}
