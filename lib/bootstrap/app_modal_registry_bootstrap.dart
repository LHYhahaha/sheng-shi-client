import '../core/modal/app_modal_presenter_registry.dart';
import '../core/modal/app_modal_provider.dart';
import '../core/modal/presenters/confirm_app_modal_presenter.dart';
import '../features/player/presentation/modal/player_app_modal_presenter.dart';

/// ProviderScope override：注册 confirm + Player 全局弹窗 presenter。
final appModalRegistryOverrides = [
  appModalPresenterRegistryProvider.overrideWith((ref) {
    return AppModalPresenterRegistry([
      ConfirmAppModalPresenter(),
      const PlayerAppModalPresenter(),
    ]);
  }),
];
