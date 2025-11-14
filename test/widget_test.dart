import 'package:flutter_test/flutter_test.dart';

import 'package:lidle/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LidleApp());
    await tester.pumpAndSettle();

    // Verify that our app starts and shows main content
    // The app should load without crashing and show basic UI elements
    expect(find.byType(LidleApp), findsOneWidget);
  });
}
