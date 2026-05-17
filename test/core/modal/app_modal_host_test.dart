import 'package:drama_client/app/app_root_navigator_key.dart';
import 'package:drama_client/core/modal/app_modal_policy.dart';
import 'package:drama_client/core/modal/app_modal_provider.dart';
import 'package:drama_client/core/modal/app_modal_host.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_service.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppModalHost confirm skeleton', () {
    Future<void> pumpAndShowConfirm(
      WidgetTester tester, {
      AppModalDismissPolicy dismissPolicy = AppModalDismissPolicy.standard,
      required void Function(ConfirmResult result) onResult,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: appRootNavigatorKey,
            home: AppModalHost(
              child: _ConfirmLauncher(
                dismissPolicy: dismissPolicy,
                onResult: onResult,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open_confirm'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirm returns confirmed', (tester) async {
      ConfirmResult? captured;
      await pumpAndShowConfirm(tester, onResult: (result) => captured = result);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(captured, isA<ConfirmResult>());
      expect(captured!.isConfirmed, isTrue);
    });

    testWidgets('cancel returns cancelled', (tester) async {
      ConfirmResult? captured;
      await pumpAndShowConfirm(tester, onResult: (result) => captured = result);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(captured!.isCancelled, isTrue);
    });

    testWidgets('barrier dismiss returns dismissed when allowed', (
      tester,
    ) async {
      ConfirmResult? captured;
      await pumpAndShowConfirm(tester, onResult: (result) => captured = result);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(captured!.isDismissed, isTrue);
    });

    testWidgets('records request metadata on confirm', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: appRootNavigatorKey,
            home: AppModalHost(
              child: _ConfirmLauncher(
                requestId: 'req_meta_1',
                source: AppModalSource.forYou,
                priority: AppModalPriority.critical,
                onResult: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open_confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final controller = container.read(appModalControllerProvider);
      expect(controller.hasCurrent, isFalse);
    });
  });
}

class _ConfirmLauncher extends ConsumerStatefulWidget {
  const _ConfirmLauncher({
    required this.onResult,
    this.requestId,
    this.source = AppModalSource.system,
    this.priority = AppModalPriority.normal,
    this.dismissPolicy = AppModalDismissPolicy.standard,
  });

  final void Function(ConfirmResult result) onResult;
  final String? requestId;
  final AppModalSource source;
  final AppModalPriority priority;
  final AppModalDismissPolicy dismissPolicy;

  @override
  ConsumerState<_ConfirmLauncher> createState() => _ConfirmLauncherState();
}

class _ConfirmLauncherState extends ConsumerState<_ConfirmLauncher> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final controller = ref.read(appModalControllerProvider);
            final service = ref.read(appModalServiceProvider);
            final request = ConfirmModalRequest(
              requestId: widget.requestId ?? controller.nextRequestId(),
              source: widget.source,
              priority: widget.priority,
              dismissPolicy: widget.dismissPolicy,
              title: 'Confirm title',
              message: 'Confirm message',
              confirmLabel: 'OK',
              cancelLabel: 'Not now',
            );
            final result = await service.showConfirm(request);
            widget.onResult(result);
          },
          child: const Text('open_confirm'),
        ),
      ),
    );
  }
}
