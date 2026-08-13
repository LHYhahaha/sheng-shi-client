import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/features/player/application/player_like_controller.dart';
import 'package:drama_client/features/player/data/player_remote_data_source_provider.dart';
import 'package:drama_client/features/player/data/remote/player_remote_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('like controller rebuilds when its remote data source changes', () {
    var sourceGeneration = 0;
    final sourceGenerationProvider = Provider<int>((_) => sourceGeneration);
    final firstDataSource = PlayerRemoteDataSource(apiClient: ApiClient());
    final secondDataSource = PlayerRemoteDataSource(apiClient: ApiClient());
    final container = ProviderContainer(
      overrides: [
        playerRemoteDataSourceProvider.overrideWith(
          (ref) => ref.watch(sourceGenerationProvider) == 0
              ? firstDataSource
              : secondDataSource,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerLikeControllerProvider('1508')),
      isA<PlayerLikeState>(),
    );

    sourceGeneration = 1;
    container.invalidate(sourceGenerationProvider);

    expect(
      container.read(playerLikeControllerProvider('1508')),
      isA<PlayerLikeState>(),
    );
  });
}
