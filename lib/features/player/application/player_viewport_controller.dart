import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_rebuild_diagnostics.dart';

final playerViewportControllerProvider =
    NotifierProvider.family<
      PlayerViewportController,
      PlayerViewportState,
      String
    >(PlayerViewportController.new);

/// 视口手势阶段：drag 期间禁止 settled runtime（见 [PlayerFeedEngine]）。
enum PlayerViewportScrollPhase {
  /// 已落位，可执行 access/play/preload。
  idle,

  /// 用户手指拖动 PageView：仅更新 candidate，不 settled。
  dragging,

  /// 手指抬起、等待 PageView 惯性结束。
  settling,
}

/// PageView 视口状态。
///
/// - [currentIndex] / [candidateIndex]：拖动中跟手页，可不同于 [settledIndex]。
/// - [settledIndex] + [settledItemId]：唯一可触发 runtime 的落位项。
/// - [generation]：settled 变更序号，供 listener 去重。
class PlayerViewportState {
  const PlayerViewportState({
    required this.scrollPhase,
    required this.currentIndex,
    required this.candidateIndex,
    required this.settledIndex,
    required this.generation,
    this.settledItemId,
  });

  const PlayerViewportState.initial()
    : scrollPhase = PlayerViewportScrollPhase.idle,
      currentIndex = 0,
      candidateIndex = 0,
      settledIndex = 0,
      settledItemId = null,
      generation = 0;

  final PlayerViewportScrollPhase scrollPhase;
  final int currentIndex;
  final int candidateIndex;
  final int settledIndex;
  final String? settledItemId;
  final int generation;

  PlayerViewportState copyWith({
    PlayerViewportScrollPhase? scrollPhase,
    int? currentIndex,
    int? candidateIndex,
    int? settledIndex,
    String? settledItemId,
    int? generation,
    bool clearSettledItemId = false,
  }) {
    return PlayerViewportState(
      scrollPhase: scrollPhase ?? this.scrollPhase,
      currentIndex: currentIndex ?? this.currentIndex,
      candidateIndex: candidateIndex ?? this.candidateIndex,
      settledIndex: settledIndex ?? this.settledIndex,
      settledItemId: clearSettledItemId
          ? null
          : settledItemId ?? this.settledItemId,
      generation: generation ?? this.generation,
    );
  }
}

class PlayerViewportController extends Notifier<PlayerViewportState> {
  PlayerViewportController(this.sessionKey);

  final String sessionKey;

  @override
  PlayerViewportState build() => const PlayerViewportState.initial();

  void initialize({required int index, required String? itemId}) {
    if (state.currentIndex == index &&
        state.candidateIndex == index &&
        state.settledIndex == index &&
        state.settledItemId == itemId &&
        state.scrollPhase == PlayerViewportScrollPhase.idle) {
      return;
    }
    state = state.copyWith(
      scrollPhase: PlayerViewportScrollPhase.idle,
      currentIndex: index,
      candidateIndex: index,
      settledIndex: index,
      settledItemId: itemId,
      generation: state.generation + 1,
    );
    PlayerRebuildDiagnostics.recordTiming(
      'viewportSettled',
      itemId: itemId,
      details:
          'session=$sessionKey index=$index generation=${state.generation}',
    );
  }

  /// 手指按下开始拖动：进入 dragging，禁止 runtime（不更新 settled）。
  void markScrollStart() {
    if (state.scrollPhase == PlayerViewportScrollPhase.dragging) {
      return;
    }
    state = state.copyWith(scrollPhase: PlayerViewportScrollPhase.dragging);
    PlayerRebuildDiagnostics.recordTiming(
      'viewportScrollStart',
      details:
          'session=$sessionKey current=${state.currentIndex} candidate=${state.candidateIndex} generation=${state.generation}',
    );
  }

  /// PageView 跟手页变化：只更新 candidate/current，仍不算 settled。
  void markPageChanged(int index) {
    if (state.candidateIndex == index && state.currentIndex == index) {
      return;
    }
    state = state.copyWith(currentIndex: index, candidateIndex: index);
    PlayerRebuildDiagnostics.recordTiming(
      'viewportPageChanged',
      details:
          'session=$sessionKey index=$index phase=${state.scrollPhase.name} generation=${state.generation}',
    );
  }

  void markScrollEnd() {
    if (state.scrollPhase == PlayerViewportScrollPhase.settling) {
      return;
    }
    state = state.copyWith(scrollPhase: PlayerViewportScrollPhase.settling);
    PlayerRebuildDiagnostics.recordTiming(
      'viewportSettling',
      details:
          'session=$sessionKey candidate=${state.candidateIndex} generation=${state.generation}',
    );
  }

  /// 惯性结束且 index 对齐：写入 settled 并回到 idle，供 engine listener 触发 runtime。
  void settle({required int index, required String? itemId}) {
    if (state.settledIndex == index &&
        state.settledItemId == itemId &&
        state.scrollPhase == PlayerViewportScrollPhase.idle) {
      return;
    }
    state = state.copyWith(
      scrollPhase: PlayerViewportScrollPhase.idle,
      currentIndex: index,
      candidateIndex: index,
      settledIndex: index,
      settledItemId: itemId,
      generation: state.generation + 1,
    );
    PlayerRebuildDiagnostics.recordTiming(
      'viewportSettled',
      itemId: itemId,
      details:
          'session=$sessionKey index=$index generation=${state.generation}',
    );
  }
}
