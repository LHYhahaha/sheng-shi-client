import 'package:drama_client/features/player/application/player_frame_jank_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summarizes slow build and raster frames for a playback phase', () {
    final diagnostics = PlayerFrameJankDiagnostics(
      sessionKey: 'single:drama-a:1',
      slowFrameThreshold: const Duration(milliseconds: 16),
      severeFrameThreshold: const Duration(milliseconds: 32),
    );

    diagnostics
      ..markPhase('entry_to_first_frame', itemId: 'drama-a-ep-1')
      ..recordFrameDurations(
        buildDuration: const Duration(milliseconds: 8),
        rasterDuration: const Duration(milliseconds: 12),
      )
      ..recordFrameDurations(
        buildDuration: const Duration(milliseconds: 18),
        rasterDuration: const Duration(milliseconds: 10),
      )
      ..recordFrameDurations(
        buildDuration: const Duration(milliseconds: 12),
        rasterDuration: const Duration(milliseconds: 40),
      );

    final summary = diagnostics.exportSummary();

    expect(summary, contains('phase=entry_to_first_frame'));
    expect(summary, contains('item=drama-a-ep-1'));
    expect(summary, contains('frames=3'));
    expect(summary, contains('slowFrames=2'));
    expect(summary, contains('severeFrames=1'));
    expect(summary, contains('maxBuildMs=18'));
    expect(summary, contains('maxRasterMs=40'));
  });

  test('resets counters when playback phase changes', () {
    final diagnostics = PlayerFrameJankDiagnostics(
      sessionKey: 'single:drama-a:1',
      slowFrameThreshold: const Duration(milliseconds: 16),
      severeFrameThreshold: const Duration(milliseconds: 32),
    );

    diagnostics
      ..markPhase('page_scroll', itemId: 'drama-a-ep-1')
      ..recordFrameDurations(
        buildDuration: const Duration(milliseconds: 22),
        rasterDuration: const Duration(milliseconds: 9),
      )
      ..markPhase('entry_to_first_frame', itemId: 'drama-a-ep-2')
      ..recordFrameDurations(
        buildDuration: const Duration(milliseconds: 4),
        rasterDuration: const Duration(milliseconds: 5),
      );

    final summary = diagnostics.exportSummary();

    expect(summary, contains('phase=entry_to_first_frame'));
    expect(summary, contains('item=drama-a-ep-2'));
    expect(summary, contains('frames=1'));
    expect(summary, contains('slowFrames=0'));
    expect(summary, isNot(contains('drama-a-ep-1')));
  });
}
