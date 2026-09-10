import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/profile/application/login_reward_provider.dart';
import 'package:drama_client/features/profile/presentation/pages/profile_page.dart';
import 'package:drama_client/features/rewards/application/reward_coins_controller.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'profile initializes and shows login reward without lifecycle errors',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entitlementControllerProvider.overrideWith(_TestEntitlements.new),
            rewardCoinsControllerProvider.overrideWith(_TestRewards.new),
            loginRewardCoinsProvider.overrideWith((ref) async => 310),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('profile_login_reward_badge')),
        findsOneWidget,
      );
      expect(find.text('+310'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

class _TestEntitlements extends EntitlementController {
  @override
  Future<bool> load() async => true;
}

class _TestRewards extends RewardCoinsController {
  @override
  Future<void> loadRemainingCoin() async {}
}
