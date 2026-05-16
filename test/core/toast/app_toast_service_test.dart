import 'package:bot_toast/bot_toast.dart';
import 'package:drama_client/core/toast/app_toast_provider.dart';
import 'package:drama_client/core/toast/app_toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('appToast success/error/info render top banner', (tester) async {
    late AppToastService toast;
    final botToastBuilder = BotToastInit();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appToastProvider.overrideWithValue(const BotAppToastService()),
        ],
        child: MaterialApp(
          builder: (context, child) => botToastBuilder(context, child),
          home: Builder(
            builder: (context) {
              toast = ProviderScope.containerOf(context).read(appToastProvider);
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    toast.success('Unlock successful');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const ValueKey('app_toast_success')), findsOneWidget);
    expect(find.text('Unlock successful'), findsOneWidget);

    toast.error('Purchase failed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const ValueKey('app_toast_error')), findsOneWidget);
    expect(find.text('Purchase failed'), findsOneWidget);

    toast.info('Membership activated');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const ValueKey('app_toast_info')), findsOneWidget);
    expect(find.text('Membership activated'), findsOneWidget);
  });
}
