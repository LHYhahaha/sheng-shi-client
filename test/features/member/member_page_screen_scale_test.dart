import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/entitlement/domain/user_entitlement_state.dart';
import 'package:drama_client/features/home/application/vip_only_dramas_provider.dart';
import 'package:drama_client/features/home/domain/vip_only_drama.dart';
import 'package:drama_client/features/member/presentation/pages/member_page.dart';
import 'package:drama_client/features/rewards/application/member_points_controller.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('member center scales its outer layout on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementControllerProvider.overrideWith(_MemberEntitlements.new),
          memberPointsControllerProvider.overrideWith(_MemberPoints.new),
          vipOnlyDramasProvider.overrideWith(
            (ref) async => const VipOnlyDramaCollection(limit: 0, dramas: []),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              ScreenUtilInit(designSize: const Size(375, 812), child: child),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MemberPage(),
        ),
      ),
    );
    await tester.pump();

    final pageList = tester.widget<ListView>(find.byType(ListView).first);
    expect(
      pageList.padding,
      const EdgeInsets.fromLTRB(0, 12 * 320 / 375, 0, 32 * 320 / 375),
    );
    expect(tester.takeException(), isNull);
  });
}

class _MemberEntitlements extends EntitlementController {
  @override
  UserEntitlementState build() => const UserEntitlementState(
    isGuest: false,
    isMember: true,
    coinBalance: 0,
    autoUnlockEnabled: false,
    unlockedEpisodeIds: <String>{},
    membershipExpiresAt: null,
  );

  @override
  Future<bool> refreshFromServer() async => true;
}

class _MemberPoints extends MemberPointsController {
  @override
  Future<void> loadDailyDetail() async {}
}
