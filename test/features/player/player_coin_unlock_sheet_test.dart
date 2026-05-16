import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/player/presentation/widgets/player_action_sheets.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet auto unlock copy has no Anto typo', () {
    const l10n = AppLocalizations(Locale('en'));
    expect(l10n.walletAutoUnlockNextEpisode, 'Auto-unlock the next episode');
    expect(
      l10n.walletAutoUnlockNextEpisode.toLowerCase(),
      isNot(contains('anto')),
    );
  });

  testWidgets('switch reflects entitlement autoUnlockEnabled when on', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(
            MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlayerCoinUnlockSheet(
              price: 60,
              balance: 4000,
              onConfirm: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await container.read(entitlementControllerProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('player_coin_unlock_auto_next_switch')),
          )
          .value,
      isTrue,
    );
  });
}

void _noop() {}
