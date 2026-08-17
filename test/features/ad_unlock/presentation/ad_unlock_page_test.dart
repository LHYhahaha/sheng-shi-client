import 'package:drama_client/features/ad_unlock/domain/ad_unlock_models.dart';
import 'package:drama_client/features/ad_unlock/presentation/ad_unlock_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets('shows retry action after a confirmation failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AdUnlockPage(
            session: _session,
            dramaId: '100',
            episodeId: '200',
          ),
        ),
      ),
    );
    expect(find.text('Retry unlock'), findsNothing);
  });

  testWidgets('keeps the close action disabled while watch time remains', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AdUnlockPage(
            session: _pendingSession,
            dramaId: '100',
            episodeId: '200',
          ),
        ),
      ),
    );

    expect(find.text('Close in 12s'), findsOneWidget);
    final closeGesture = find.ancestor(
      of: find.text('Close in 12s'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.widget<GestureDetector>(closeGesture).onTap, isNull);
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
