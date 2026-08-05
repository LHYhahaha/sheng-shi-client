import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsPageContext {
  const AnalyticsPageContext({this.currentPage, this.previousPage});

  final String? currentPage;
  final String? previousPage;
}

class AnalyticsPageContextController extends Notifier<AnalyticsPageContext> {
  @override
  AnalyticsPageContext build() => const AnalyticsPageContext();

  AnalyticsPageContext get current => state;

  void show(String pageName, {String? previousPage}) {
    state = AnalyticsPageContext(
      currentPage: pageName,
      previousPage: previousPage,
    );
  }

  void clear() => state = const AnalyticsPageContext();
}

final analyticsPageContextProvider =
    NotifierProvider<AnalyticsPageContextController, AnalyticsPageContext>(
      AnalyticsPageContextController.new,
    );
