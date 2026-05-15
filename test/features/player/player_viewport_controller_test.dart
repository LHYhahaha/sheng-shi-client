import 'package:drama_client/features/player/application/player_viewport_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('tracks drag candidate separately from settled item', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = playerViewportControllerProvider('single:test');
    final controller = container.read(provider.notifier);

    controller.initialize(index: 0, itemId: 'ep-1');
    controller.markScrollStart();
    controller.updatePageOffset(0.52);
    controller.markPageChanged(1);

    var state = container.read(provider);
    expect(state.scrollPhase, PlayerViewportScrollPhase.dragging);
    expect(state.currentIndex, 1);
    expect(state.candidateIndex, 1);
    expect(state.settledIndex, 0);
    expect(state.settledItemId, 'ep-1');

    controller.markScrollEnd();
    state = container.read(provider);
    expect(state.scrollPhase, PlayerViewportScrollPhase.settling);
    expect(state.settledIndex, 0);

    controller.settle(index: 1, itemId: 'ep-2', pageOffset: 1);
    state = container.read(provider);
    expect(state.scrollPhase, PlayerViewportScrollPhase.idle);
    expect(state.currentIndex, 1);
    expect(state.candidateIndex, 1);
    expect(state.settledIndex, 1);
    expect(state.settledItemId, 'ep-2');
  });

  test('fast page changes settle only the final candidate', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = playerViewportControllerProvider('single:test');
    final controller = container.read(provider.notifier);

    controller.initialize(index: 0, itemId: 'ep-1');
    controller.markScrollStart();
    controller.markPageChanged(1);
    controller.markPageChanged(2);
    controller.markScrollEnd();
    controller.settle(index: 2, itemId: 'ep-3', pageOffset: 2);

    final state = container.read(provider);
    expect(state.currentIndex, 2);
    expect(state.candidateIndex, 2);
    expect(state.settledIndex, 2);
    expect(state.settledItemId, 'ep-3');
  });
}
