import 'package:drama_client/features/player/domain/player_performance_policy.dart';
import 'package:drama_client/features/player/domain/player_seek_preview_config.dart';
import 'package:drama_client/features/player/presentation/widgets/player_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSeekBar(
    WidgetTester tester, {
    required PlayerSeekPreviewConfig previewConfig,
    bool isDragging = true,
    bool hasThumbnailPreviewAsset = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: PlayerSeekBar(
                position: const Duration(seconds: 25),
                duration: const Duration(seconds: 100),
                bufferedPosition: const Duration(seconds: 60),
                previewPosition: const Duration(seconds: 40),
                thumbnailAssetPath: 'assets/images/player/recommend_1.png',
                hasThumbnailPreviewAsset: hasThumbnailPreviewAsset,
                previewConfig: previewConfig,
                isDragging: isDragging,
                showTrackLoading: false,
                enabled: true,
                onDragStart: () {},
                onDragUpdate: (_) {},
                onDragEnd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('rich 拖动没有真实预览资源时不显示缩略图', (tester) async {
    await pumpSeekBar(
      tester,
      previewConfig: PlayerSeekPreviewConfig.fromPolicy(
        PlayerPerformancePolicy.rich,
      ),
    );

    expect(
      find.byKey(const ValueKey('player_seek_thumbnail_preview')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player_seek_time_bubble')),
      findsOneWidget,
    );
  });

  testWidgets('rich 拖动有真实预览资源时才显示缩略图', (tester) async {
    await pumpSeekBar(
      tester,
      previewConfig: PlayerSeekPreviewConfig.fromPolicy(
        PlayerPerformancePolicy.rich,
      ),
      hasThumbnailPreviewAsset: true,
    );

    expect(
      find.byKey(const ValueKey('player_seek_thumbnail_preview')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('player_seek_time_bubble')), findsNothing);
  });

  testWidgets('stable 拖动无缩略图但有时间气泡', (tester) async {
    await pumpSeekBar(
      tester,
      previewConfig: PlayerSeekPreviewConfig.fromPolicy(
        PlayerPerformancePolicy.stable,
      ),
    );

    expect(
      find.byKey(const ValueKey('player_seek_thumbnail_preview')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('player_seek_time_bubble')),
      findsOneWidget,
    );
  });

  testWidgets('ultraStable 拖动无缩略图且无复杂气泡', (tester) async {
    await pumpSeekBar(
      tester,
      previewConfig: PlayerSeekPreviewConfig.fromPolicy(
        PlayerPerformancePolicy.ultraStable,
      ),
    );

    expect(
      find.byKey(const ValueKey('player_seek_thumbnail_preview')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('player_seek_time_bubble')), findsNothing);
    expect(find.byKey(const ValueKey('player_seek_bar')), findsOneWidget);
  });
}
