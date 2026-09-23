import 'package:drama_client/features/ad_unlock/domain/ad_unlock_models.dart';
import 'package:drama_client/features/ad_unlock/presentation/ad_unlock_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps the in-flight post-unlock refresh attached to the route result',
    () {
      final refresh = Future<bool>.value(true);
      final result = AdUnlockRouteResult.confirmed(refreshFuture: refresh);

      expect(result.refreshFuture, same(refresh));
    },
  );

  testWidgets('does not show a retry action before confirmation fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => AdUnlockPage(
              session: _session,
              dramaId: '100',
              episodeId: '200',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('keeps the close action above the ad material', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => AdUnlockPage(
              session: _pendingSession,
              dramaId: '100',
              episodeId: '200',
            ),
          ),
        ),
      ),
    );

    expect(find.text('12s'), findsOneWidget);
    final closeGesture = find.ancestor(
      of: find.text('12s'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.widget<GestureDetector>(closeGesture).onTap, isNull);

    final materialGesture = find.ancestor(
      of: find.byType(Image),
      matching: find.byType(GestureDetector),
    );
    expect(
      tester
          .getRect(materialGesture)
          .contains(tester.getCenter(find.text('12s'))),
      isFalse,
    );
  });

  testWidgets('scales ad-view chrome for a narrow iPhone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => AdUnlockPage(
              session: _pendingSession,
              dramaId: '100',
              episodeId: '200',
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(LinearProgressIndicator)).height,
      closeTo(4 * 320 / 375, 0.01),
    );
  });
}

final _session = AdUnlockSession(
  sessionNo: 'session',
  material: const AdMaterial(id: 1, fileUrl: '', type: AdMaterialType.image),
  watchSeconds: 1,
  expiresAt: DateTime(2026),
  reused: false,
);

final _pendingSession = AdUnlockSession(
  sessionNo: 'pending-session',
  material: const AdMaterial(id: 2, fileUrl: '', type: AdMaterialType.image),
  watchSeconds: 12,
  expiresAt: DateTime(2026),
  reused: false,
);
