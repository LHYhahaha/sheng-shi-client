import 'package:drama_client/bootstrap/app_modal_registry_bootstrap.dart';
import 'package:drama_client/core/modal/app_modal_provider.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_app_modal_presenter.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_modal_channels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app modal registry includes auth login presenter', () {
    final container = ProviderContainer(overrides: appModalRegistryOverrides);
    addTearDown(container.dispose);

    final registry = container.read(appModalPresenterRegistryProvider);
    final request = FeatureAppModalRequest(
      requestId: 'auth_registry',
      source: AppModalSource.auth,
      channel: AuthModalChannels.login,
      type: AppModalType.login,
    );

    expect(registry.resolve(request), isA<AuthAppModalPresenter>());
  });
}
