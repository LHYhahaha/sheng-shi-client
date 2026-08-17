import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/features/ad_unlock/presentation/ad_unlock_prompt_dialog.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns true when the watch-ad action is tapped', (
    tester,
  ) async {
    bool? result;
    final sink = AnalyticsInMemoryEventSink();
    final analytics = AnalyticsService(
      contextReader: () => const AnalyticsContext(
        platform: 'android',
        appVersion: '1.0.3',
        language: 'en',
      ),
      eventSink: sink,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAdUnlockPromptDialog(
                context,
                coverUrl: null,
                watchedToday: 0,
                dailyLimit: 5,
                analytics: analytics,
                dramaId: '722',
                episodeId: '1101',
                dramaAccessType: 'normal',
                adMaterialId: '300',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Watch this episode free?'), findsOneWidget);
    expect(find.text('Watched today (0/5)'), findsOneWidget);

    await tester.tap(find.text('Watch Ad to unlock'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(sink.events.map((event) => event.eventName), [
      'popup_show',
      'element_click',
      'popup_close',
    ]);
    expect(sink.events.first.eventParams, sink.events.last.eventParams);
    expect(sink.events[1].eventParams, {
      'element_name': 'ad_unlock_button',
      'drama_id': '722',
      'episode_id': '1101',
      'drama_access_type': 'normal',
      'ad_material_id': '300',
    });
  });
}
