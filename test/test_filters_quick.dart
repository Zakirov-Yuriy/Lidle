/// Quick test to run filter diagnostics
/// 
/// Run with: flutter test test/test_filters_quick.dart
/// Or embed in your test suite

import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/services/filter_tester.dart';

void main() {
  group('Filter Diagnostics', () {
    test('Test all filters for Real Estate category', () async {
      print('\n╔═════════════════════════════════════════════╗');
      print('║  Running Filter Diagnostic Tests            ║');
      print('╚═════════════════════════════════════════════╝\n');

      final results = await FilterTester.runDiagnostics(
        categoryId: 2,
        categoryName: 'Real Estate',
      );

      print('\n${results.report}');
      
      // Print JSON for automated parsing if needed
      print('\nJSON Report:');
      print(results.jsonReport);

      // Basic assertions
      expect(results.baselineCount, greaterThan(0),
          reason: 'Should have at least some listings');
      expect(results.totalFilters, greaterThan(0),
          reason: 'Should load at least some filters');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
