import 'package:drama_client/features/home/application/vip_only_dramas_provider.dart';
import 'package:drama_client/features/home/domain/vip_only_drama.dart';
import 'package:drama_client/features/home/presentation/widgets/vip_only_dramas_section.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VIP drama rail scales its fixed height on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vipOnlyDramasProvider.overrideWith(
            (ref) async => VipOnlyDramaCollection(
              limit: 6,
              dramas: List.generate(
                6,
                (index) => VipOnlyDrama(
                  id: '$index',
                  coverUrl: '',
                  title: 'VIP Drama $index',
                  summary: '',
                ),
              ),
            ),
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
          home: Scaffold(body: VipOnlyDramasSection(onDramaTap: (_, _) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('vip_only_dramas_list'))).height,
      closeTo(320 / 3.2 / 0.68 + (34 + 6) * 320 / 375, 0.01),
    );
  });
}
