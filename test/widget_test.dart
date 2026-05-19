import 'package:drama_client/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DramaClientApp()));

    expect(find.text('Short Drama Client'), findsOneWidget);
    expect(find.text('Open demo player'), findsOneWidget);
  });
}
