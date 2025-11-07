
import 'package:flutter_test/flutter_test.dart';

import 'package:lidle/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LidleApp());

    // Verify that our app starts.
    expect(find.text('LIDLE'), findsOneWidget);
  });
}
