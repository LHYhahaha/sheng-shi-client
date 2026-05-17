import '../core/modal/app_modal_presenter_registry.dart';
import '../core/modal/app_modal_provider.dart';
import '../core/modal/presenters/confirm_app_modal_presenter.dart';
import '../features/membership/presentation/modal/membership_app_modal_presenter.dart';
import '../features/player/presentation/modal/player_app_modal_presenter.dart';
import '../features/store/presentation/modal/store_app_modal_presenter.dart';

/// ProviderScope override：注册 confirm + feature 全局弹窗 presenter。
final appModalRegistryOverrides = [
  appModalPresenterRegistryProvider.overrideWith((ref) {
    return AppModalPresenterRegistry([
      ConfirmAppModalPresenter(),
      const PlayerAppModalPresenter(),
      const StoreAppModalPresenter(),
      const MembershipAppModalPresenter(),
    ]);
  }),
];
