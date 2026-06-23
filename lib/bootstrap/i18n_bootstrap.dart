import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/i18n.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/runtime/install_id_provider.dart';

final i18nInitializerProvider = FutureProvider<void>((ref) async {
  try {
    await ref.read(installIdProvider.future);
    final languageCode = await AppLocaleController.readSavedLanguageCode();
    await ref.read(i18nControllerProvider.notifier).initialize(languageCode);
    print('[I18n] Language package initialization completed');
  } catch (e) {
    print('[I18n] Language package initialization failed: $e');
  }
});
