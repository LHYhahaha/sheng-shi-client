import 'dart:async';

import 'package:drama_client/features/wallet/application/wallet_controller.dart';
import 'package:drama_client/features/wallet/domain/wallet_record.dart';
import 'package:drama_client/features/wallet/presentation/pages/wallet_history_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:drama_client/shared/widgets/app_empty_state.dart';
import 'package:drama_client/shared/widgets/app_peg_top_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in WalletRecordType.values) {
    testWidgets('$type shows loading until history request completes', (tester) async {
      final controller = _PendingHistoryController();
      await tester.pumpWidget(ProviderScope(
        overrides: [walletControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: WalletHistoryPage(type: type),
        ),
      ));
      expect(find.byType(AppPegTopLoader), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppPegTopLoader), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
      controller.completion.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppPegTopLoader), findsNothing);
      expect(find.byType(AppEmptyState), findsOneWidget);
    });
  }
}

class _PendingHistoryController extends WalletController {
  final completion = Completer<void>();

  @override
  WalletState build() => const WalletState.initial().copyWith(isLoading: false);

  Future<void> _loadHistory() async {
    state = state.copyWith(isHistoryLoading: true);
    await completion.future;
    state = state.copyWith(isHistoryLoading: false);
  }

  @override
  Future<void> loadTransactionRecords({String? pageToken}) => _loadHistory();
  @override
  Future<void> loadConsumptionRecords(WalletConsumptionStatus status) => _loadHistory();
  @override
  Future<void> loadRewardCoins({String? pageToken}) => _loadHistory();
}
