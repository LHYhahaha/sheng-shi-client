import 'package:drama_client/shared/widgets/app_peg_top_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the requested animated line-chart loader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPegTopLoader(size: 20, semanticLabel: 'Content is loading'),
        ),
      ),
    );

    expect(find.byType(AppPegTopLoader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppPegTopLoader),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(AppPegTopLoader)), const Size(84, 84));
    expect(find.bySemanticsLabel('Content is loading'), findsOneWidget);
  });

  testWidgets('can be rendered without playing the animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppPegTopLoader(isAnimating: false)),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AppPegTopLoader), findsOneWidget);
  });
}
