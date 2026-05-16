import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlayerChrome does not own a media_kit Video surface', () {
    final source = File(
      'lib/features/player/presentation/widgets/player_chrome.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('media_kit_video')));
    expect(source, isNot(contains('Video(')));
    expect(source, isNot(contains('videoController')));
  });

  test(
    'active playback surface remains the only named player Video surface',
    () {
      final source = File(
        'lib/features/player/presentation/pages/player_page.dart',
      ).readAsStringSync();

      expect(source, contains("ValueKey('active_playback_video_surface')"));
    },
  );
}
