import 'package:flutter/material.dart';

import 'app_modal_presenter.dart';
import 'app_modal_request.dart';
import 'app_modal_result.dart';

/// 按注册顺序解析 request 对应的 presenter。
class AppModalPresenterRegistry {
  AppModalPresenterRegistry(this._presenters);

  final List<AppModalPresenter> _presenters;

  AppModalPresenter? resolve(AppModalRequest request) {
    for (final presenter in _presenters) {
      if (presenter.handles(request)) {
        return presenter;
      }
    }
    return null;
  }

  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  }) async {
    final presenter = resolve(request);
    if (presenter == null) {
      return const AppModalPresentFailedResult();
    }
    return presenter.present(context: context, request: request);
  }
}
