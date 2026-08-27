import 'package:drama_client/shared/widgets/app_peg_top_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'uses the supplied polygon image, size, and accessibility label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppPegTopLoader(
              size: 64,
              semanticLabel: 'Content is loading',
            ),
          ),
        ),
      );

      expect(find.byType(AppPegTopLoader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppPegTopLoader),
          matching: find.byType(Image),
        ),
        findsNWidgets(3),
      );
      expect(
        tester.getSemantics(find.byType(AppPegTopLoader)).label,
        'Content is loading',
      );
      expect(tester.getSize(find.byType(AppPegTopLoader)), const Size(64, 64));
    },
  );

  testWidgets('can be rendered without playing the animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppPegTopLoader(isAnimating: false)),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(
      find.descendant(
        of: find.byType(AppPegTopLoader),
        matching: find.byType(Image),
      ),
      findsNWidgets(3),
    );
  });
}
