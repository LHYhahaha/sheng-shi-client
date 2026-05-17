import 'package:drama_client/app/app.dart';
import 'package:drama_client/core/modal/app_modal_host.dart';
import 'package:drama_client/core/toast/app_toast_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/toast/recording_app_toast_service.dart';

void main() {
  testWidgets(
    'DramaClientApp mounts AppModalHost without breaking home shell',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appToastProvider.overrideWithValue(RecordingAppToastService()),
          ],
          child: const DramaClientApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(AppModalHost), findsOneWidget);
      expect(find.byType(DramaClientApp), findsOneWidget);
    },
  );
}
