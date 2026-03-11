/// CLI Filter Diagnostic Tool
/// 
/// Запускается через: dart run test/cli_filter_diagnostic.dart
/// Тестирует все фильтры и выводит результаты

import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/api_service.dart';

void main() async {
  print('╔═════════════════════════════════════════════════════════════════╗');
  print('║                 FILTER DIAGNOSIS TOOL                          ║');
  print('║                   Real Estate (Category 2)                      ║');
  print('╚═════════════════════════════════════════════════════════════════╝\n');

  // Initialize token
  await TokenService.init();

  try {
    await runDiagnostics();
  } catch (e) {
    print('❌ Fatal error: $e');
  }
}

Future<void> runDiagnostics() async {
  const categoryId = 2; // Real Estate

  print('[STEP 1] Getting baseline (no filters)');
  print('─' * 70);

  try {
    final baselineResponse = await ApiService.getAdverts(
      categoryId: categoryId,
      limit: 100,
      token: TokenService.currentToken,
    );

    final baselineCount = baselineResponse.data.length;
    print('✅ Baseline: $baselineCount listings\n');

    print('[STEP 2] Loading all available filters');
    print('─' * 70);

    final attributes = await ApiService.getAdvertCreationAttributes(
      categoryId: categoryId,
    );

    final filters = attributes.where((a) => a.isFilter).toList();
    filters.sort((a, b) => a.id.compareTo(b.id));

    print('✅ Loaded ${filters.length} filters\n');

    print('[STEP 3] Testing each filter\n');
    print('═' * 70);

    int workingCount = 0;
    int brokenCount = 0;
    int suspiciousCount = 0;

    final results = <String, Map<String, dynamic>>{};

    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      print('\n[${i + 1}/${filters.length}] Testing: ${filter.id} - "${filter.title}"');

      final testResult = <String, dynamic>{
        'id': filter.id,
        'title': filter.title,
        'tests': <String, int>{},
      };

      if (filter.isRange) {
        print('    Type: RANGE');

        // Test min
        final minCount = await _testFilter(
          categoryId,
          _buildRangeFilter(filter.id, minValue: '1'),
        );
        testResult['tests']['min'] = minCount;
        print('    ├─ Min (≥1): $minCount results');

        // Test max
        final maxCount = await _testFilter(
          categoryId,
          _buildRangeFilter(filter.id, maxValue: '1000000'),
        );
        testResult['tests']['max'] = maxCount;
        print('    └─ Max (≤1000000): $maxCount results');
      } else if (filter.values.isNotEmpty) {
        print('    Type: PREDEFINED (${filter.values.length} values)');

        // Test first 3 values
        final testLimit = [3, filter.values.length].reduce((a, b) => a < b ? a : b);

        for (int v = 0; v < testLimit; v++) {
          final value = filter.values[v];
          final count = await _testFilter(
            categoryId,
            _buildValueFilter(filter.id, value.id),
          );

          testResult['tests']['val_${value.id}'] = count;

          final indicator = count > 0 ? '✅' : '❌';
          print('    ├─ "$indicator ${value.value}" (ID=${value.id}): $count');
        }

        if (filter.values.length > 3) {
          print('    └─ ... +${filter.values.length - 3} more values');
        }
      } else {
        print('    Type: TEXT FIELD (skip)');
        continue;
      }

      // Analyze
      bool isWorking = false;
      bool isSuspicious = false;

      for (final count in testResult['tests'].values) {
        if (count is int && count > 0 && count != baselineCount) {
          isWorking = true;
        }
        if (count is int && count == baselineCount) {
          isSuspicious = true;
        }
      }

      if (isWorking) {
        workingCount++;
        print('    ✅ WORKING');
      } else if (isSuspicious) {
        suspiciousCount++;
        print('    ⚠️  SUSPICIOUS (same count as baseline!)');
      } else {
        brokenCount++;
        print('    ❌ BROKEN');
      }

      results[filter.id.toString()] = testResult;
    }

    // Final report
    print('\n╔═════════════════════════════════════════════════════════════════╗');
    print('║                      DIAGNOSTIC REPORT                          ║');
    print('╚═════════════════════════════════════════════════════════════════╝\n');

    print('Baseline (no filters): $baselineCount listings\n');

    print('SUMMARY:');
    print('  ✅ Working filters: $workingCount');
    print('  ⚠️  Suspicious filters: $suspiciousCount');
    print('  ❌ Broken filters: $brokenCount');
    print('  Total tested: ${filters.length}\n');

    final successRate = filters.length > 0
        ? ((workingCount / filters.length) * 100).toStringAsFixed(1)
        : '0';
    print('Success rate: $successRate%\n');

    if (workingCount == filters.length) {
      print('✅ All filters are working correctly!');
    } else if (suspiciousCount > 0) {
      print('⚠️  WARNING: Some filters return same count as baseline.');
      print('   This indicates server-side filtering is NOT working!');
      print('   The API ignores filter parameters and returns all results.\n');

      print('Suspicious filters:');
      for (final entry in results.entries) {
        final data = entry.value;
        final tests = data['tests'] as Map<String, dynamic>;

        bool suspicious = false;
        for (final count in tests.values) {
          if (count is int && count == baselineCount) {
            suspicious = true;
            break;
          }
        }

        if (suspicious) {
          print('  - ${data['id']}: "${data['title']}"');
        }
      }
    } else if (brokenCount > 0) {
      print('❌ ERROR: Most or all filters are not working!');
      print('   Either server implementation is broken or API changed.\n');

      print('Broken filters:');
      for (final entry in results.entries) {
        final data = entry.value;
        print('  - ${data['id']}: "${data['title']}"');
      }
    }
  } catch (e, st) {
    print('❌ Error: $e');
    print(st);
  }
}

Future<int> _testFilter(int categoryId, Map<String, dynamic> filters) async {
  try {
    final response = await ApiService.getAdverts(
      categoryId: categoryId,
      filters: filters,
      limit: 100,
      token: TokenService.currentToken,
    );
    return response.data.length;
  } catch (e) {
    print('       Error: $e');
    return -1;
  }
}

Map<String, dynamic> _buildRangeFilter(int attrId, {String? minValue, String? maxValue}) {
  return {
    'values': {
      attrId.toString(): {
        if (minValue != null) 'min': minValue,
        if (maxValue != null) 'max': maxValue,
      },
    },
  };
}

Map<String, dynamic> _buildValueFilter(int attrId, int valueId) {
  return {
    'value_selected': {
      attrId.toString(): [valueId],
    },
  };
}
