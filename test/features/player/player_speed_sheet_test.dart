import 'package:drama_client/features/player/presentation/widgets/player_action_sheets.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('six rates, selection, immediate callback and dismissal', (
    tester,
  ) async {
    double? selected;
    final currentRate = ValueNotifier<double>(1.0);
    addTearDown(currentRate.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ValueListenableBuilder<double>(
                  valueListenable: currentRate,
                  builder: (_, rate, _) => PlayerSpeedSheet(
                    selectedRate: rate,
                    onRateSelected: (rate) => selected = rate,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    for (final rate in [0.75, 1.0, 1.25, 1.5, 2.0, 3.0]) {
      expect(find.text('${rate}x'), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('player_speed_selected_check')),
      findsOneWidget,
    );
    currentRate.value = 3.0;
    await tester.pump();
    final check = find.byKey(const ValueKey('player_speed_selected_check'));
    expect(check, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('player_speed_option_3.0')),
        matching: check,
      ),
      findsOneWidget,
    );
    final press = await tester.startGesture(
      tester.getCenter(find.text('1.25x')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(check, findsOneWidget);
    expect(selected, isNull);
    await press.up();
    await tester.pumpAndSettle();
    expect(selected, 1.25);
    expect(find.byType(PlayerSpeedSheet), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerSpeedSheet), findsNothing);
    expect(selected, 1.25);
  });
}
