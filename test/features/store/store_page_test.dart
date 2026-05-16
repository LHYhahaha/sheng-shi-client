import 'package:drama_client/core/toast/app_toast_provider.dart';
import 'package:drama_client/features/store/presentation/pages/store_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/toast/recording_app_toast_service.dart';

void main() {
  testWidgets('store purchase success closes and reopens idle', (tester) async {
    await tester.pumpWidget(_buildStorePage());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text(r'$ 29.99').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm purchase'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(find.text('Processing mock purchase...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Mock purchase completed.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Confirm purchase'), findsNothing);

    await tester.tap(find.text(r'$14.99').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();

    expect(
      find.text('This is a mock confirmation for MVP testing.'),
      findsOneWidget,
    );
    expect(find.text('Mock purchase completed.'), findsNothing);
  });

  testWidgets('store restore uses app toast not snackbar', (tester) async {
    final toast = RecordingAppToastService();
    await tester.pumpWidget(_buildStorePage(toastService: toast));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(toast.infos, contains('Restore is unavailable in mock mode.'));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(ScaffoldMessenger), findsWidgets);
  });

  testWidgets('store purchase cancel closes and restore shows mock feedback', (
    tester,
  ) async {
    final toast = RecordingAppToastService();
    await tester.pumpWidget(_buildStorePage(toastService: toast));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(toast.infos, contains('Restore is unavailable in mock mode.'));

    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Mock purchase cancelled.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Confirm purchase'), findsNothing);
  });
}

Widget _buildStorePage({RecordingAppToastService? toastService}) {
  final toast = toastService ?? RecordingAppToastService();
  return ProviderScope(
    overrides: [appToastProvider.overrideWithValue(toast)],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StorePage(),
    ),
  );
}
