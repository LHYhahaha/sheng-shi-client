import 'package:drama_client/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));

    expect(find.text('KillgBox'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Found You,Hea'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('My list'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('switches between bottom navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));

    await tester.tap(find.text('My list'));
    await tester.pumpAndSettle();
    expect(
      find.text('Collection list and play list come in M4.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Guest/login state, wallet, and membership entries come in M4.',
      ),
      findsOneWidget,
    );
  });
}
