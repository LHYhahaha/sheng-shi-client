import 'package:flutter/material.dart';

import 'app_modal_request.dart';
import 'app_modal_result.dart';

/// 将 [AppModalRequest] 展示为 UI 的策略；由 app 层注册，core 不依赖 feature。
abstract class AppModalPresenter {
  bool handles(AppModalRequest request);

  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  });
}
