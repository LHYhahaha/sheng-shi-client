import 'package:drama_client/features/auth/application/auth_controller.dart';
import 'package:drama_client/features/auth/application/phone_login_config_provider.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_login_intent.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_login_modal_sheet.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_modal_payloads.dart';
import 'package:drama_client/features/auth/presentation/widgets/auth_action_button.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login sheet scales provider buttons on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_StableAuthController.new),
          phoneLoginEnabledProvider.overrideWith((ref) async => false),
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
          home: const Scaffold(
            body: AuthLoginModalSheet(
              payload: AuthLoginModalPayload(
                intent: AuthLoginIntent.userInitiated,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(AuthActionButton).first).height,
      closeTo(48 * 320 / 375, .01),
    );
    expect(tester.takeException(), isNull);
  });
}

class _StableAuthController extends AuthController {
  @override
  AuthState build() =>
      const AuthState(isLoading: false, session: AuthSession.guest());

  @override
  Future<void> load() async {}
}
