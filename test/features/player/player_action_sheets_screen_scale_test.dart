import 'package:drama_client/features/player/presentation/widgets/player_action_sheets.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scales the compact player sheet height from the design width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PlayerShareLoadingSheet(),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const Key('player_compact_sheet_surface')))
          .height,
      closeTo(249 * 320 / 375, 0.01),
    );
  });

  testWidgets('scales the settings sheet title from the design width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const Scaffold(
            body: PlayerPlaybackSettingsSheet(
              languageLabel: 'English',
              qualityLabel: 'HD',
              canShowLanguage: true,
              canShowQuality: false,
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Playback Settings'));
    expect(title.style?.fontSize, closeTo(18 * 320 / 375, 0.01));
  });

  testWidgets('scales the speed option height from the design width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const Scaffold(
            body: PlayerSpeedSheet(selectedRate: 1, onRateSelected: _ignore),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('player_speed_option_1.0')))
          .height,
      closeTo(56 * 320 / 375, 0.01),
    );
  });
}

void _ignore(double _) {}
