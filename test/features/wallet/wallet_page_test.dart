import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/wallet/presentation/pages/wallet_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wallet switch follows entitlement autoUnlockEnabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(
            MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: WalletPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WalletPage)),
    );
    await container
        .read(entitlementControllerProvider.notifier)
        .setAutoUnlockEnabled(true);
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
