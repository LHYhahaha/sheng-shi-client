import 'package:drama_client/app/presentation/widgets/novashort_splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the NovaShort launch identity', (tester) async {
    await tester.pumpWidget(const NovaShortSplashPage());

    expect(find.text('NovaShort'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF0A0014),
    );
  });
}
