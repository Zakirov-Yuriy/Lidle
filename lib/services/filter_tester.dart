/// Filter Testing Module
/// 
/// Используется для диагностики фильтров
/// Может быть интегрирован в любую часть приложения
///
/// Использование:
/// ```
/// final results = await FilterTester.runDiagnostics(categoryId: 2);
/// print(results.report);
/// ```

import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/models/filter_models.dart';

class FilterTestResult {
  String title;
  
  int baselineCount = 0;
  int totalFilters = 0;
  int workingCount = 0;
  int suspiciousCount = 0;
  int brokenCount = 0;

  final Map<int, _FilterResult> filterResults = {};

  FilterTestResult({this.title = 'Category'});

  String get report {
    final buf = StringBuffer();

    buf.writeln('╔═════════════════════════════════════════════════════════════╗');
    buf.writeln('║         FILTER DIAGNOSTIC REPORT                            ║');
    buf.writeln('╚═════════════════════════════════════════════════════════════╝\n');

    buf.writeln('Category: $title');
    buf.writeln('Baseline (no filters): $baselineCount listings\n');

    buf.writeln('SUMMARY:');
    buf.writeln('  ✅ Working: $workingCount');
    buf.writeln('  ⚠️  Suspicious: $suspiciousCount');
    buf.writeln('  ❌ Broken: $brokenCount');
    buf.writeln('  Total: $totalFilters\n');

    if (totalFilters > 0) {
      final pct = ((workingCount / totalFilters) * 100).toStringAsFixed(1);
      buf.writeln('Success Rate: $pct%\n');
    }

    // List working filters
    if (workingCount > 0) {
      buf.writeln('WORKING FILTERS:');
      for (final result in filterResults.values) {
        if (result.isWorking == true) {
          buf.writeln('  ✅ ${result.id}: ${result.title}');
        }
      }
      buf.writeln('');
    }

    // List suspicious filters
    if (suspiciousCount > 0) {
      buf.writeln('SUSPICIOUS FILTERS (returned same count as baseline):');
      for (final result in filterResults.values) {
        if (result.isSuspicious == true) {
          buf.writeln('  ⚠️  ${result.id}: ${result.title}');
        }
      }
      buf.writeln('');
    }

    // List broken filters
    if (brokenCount > 0) {
      buf.writeln('BROKEN FILTERS:');
      for (final result in filterResults.values) {
        if (result.isWorking == false) {
          buf.writeln('  ❌ ${result.id}: ${result.title}');
        }
      }
      buf.writeln('');
    }

    // Assessment
    buf.writeln('═' * 60);
    if (workingCount == totalFilters) {
      buf.writeln('✅ All filters working correctly!');
    } else if (workingCount > totalFilters / 2) {
      buf.writeln('⚠️  Most filters work, some issues present.');
    } else if (suspiciousCount == totalFilters) {
      buf.writeln('❌ SERVER-SIDE FILTERING NOT WORKING!');
      buf.writeln('   API ignores filter parameters.');
      buf.writeln('   All filters return same results as baseline.');
    } else {
      buf.writeln('❌ Severe filtering issues detected.');
    }

    return buf.toString();
  }

  String get jsonReport {
    final data = {
      'title': title,
      'baseline': baselineCount,
      'summary': {
        'working': workingCount,
        'suspicious': suspiciousCount,
        'broken': brokenCount,
        'total': totalFilters,
      },
      'filters': {
        for (final result in filterResults.values)
          result.id.toString(): {
            'title': result.title,
            'type': result.type,
            'status': result.isWorking == true
                ? 'working'
                : result.isSuspicious == true
                    ? 'suspicious'
                    : 'broken',
            'tests': {
              for (final test in result.tests.entries)
                test.key: {
                  'count': test.value.count,
                  'name': test.value.name,
                  'working': test.value.isWorking,
                },
            },
          },
      },
    };
    return data.toString();
  }
}

class _FilterResult {
  final int id;
  final String title;
  final String type;
  final Map<String, _TestResult> tests = {};

  bool? isWorking;
  bool? isSuspicious;

  _FilterResult({
    required this.id,
    required this.title,
    required this.type,
  });

  void analyze(int baselineCount) {
    if (tests.isEmpty) {
      isWorking = null;
      return;
    }

    bool anyDifferent = false;
    bool anySameAsBaseline = false;

    for (final test in tests.values) {
      if (test.count > 0 && test.count != baselineCount) {
        anyDifferent = true;
      }
      if (test.count == baselineCount) {
        anySameAsBaseline = true;
      }
    }

    isWorking = anyDifferent;
    isSuspicious = anySameAsBaseline && !anyDifferent;
  }
}

class _TestResult {
  final String name;
  final int count;
  final int? valueId;
  final String? error;

  _TestResult({
    required this.name,
    required this.count,
    this.valueId,
    this.error,
  });

  bool get isWorking => count > 0 && error == null;
}

class FilterTester {
  /// Run full diagnostic test for a category
  static Future<FilterTestResult> runDiagnostics({
    required int categoryId,
    String categoryName = 'Category',
    String? token,
  }) async {
    token ??= TokenService.currentToken;
    
    final result = FilterTestResult(title: categoryName);

    try {
      // Step 1: Get baseline
      print('⏳ Getting baseline count...');
      final baselineResp = await ApiService.getAdverts(
        categoryId: categoryId,
        limit: 100,
        token: token,
      );
      result.baselineCount = baselineResp.data.length;
      print('✅ Baseline: ${result.baselineCount} listings');

      // Step 2: Load filters
      print('\n⏳ Loading filters...');
      final attributes = await ApiService.getAdvertCreationAttributes(
        categoryId: categoryId,
      );
      final filters = attributes.where((a) => a.isFilter).toList();
      filters.sort((a, b) => a.id.compareTo(b.id));
      result.totalFilters = filters.length;
      print('✅ Loaded ${filters.length} filters');

      // Step 3: Test each filter
      print('\n⏳ Testing filters...');
      for (final filter in filters) {
        await _testFilter(filter, categoryId, result, token);
      }

      // Finalize
      for (final filterResult in result.filterResults.values) {
        filterResult.analyze(result.baselineCount);
        
        if (filterResult.isWorking == true) {
          result.workingCount++;
        } else if (filterResult.isSuspicious == true) {
          result.suspiciousCount++;
        } else {
          result.brokenCount++;
        }
      }

      return result;
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  static Future<void> _testFilter(
    Attribute filter,
    int categoryId,
    FilterTestResult result,
    String? token,
  ) async {
    try {
      final filterResult = _FilterResult(
        id: filter.id,
        title: filter.title,
        type: filter.isRange ? 'RANGE' : 'PREDEFINED',
      );

      if (filter.isRange) {
        // Test min
        final minCount = await _getCount(
          categoryId,
          _buildRangeFilter(filter.id, minValue: '1'),
          token,
        );
        filterResult.tests['min'] = _TestResult(
          name: 'min ≥ 1',
          count: minCount,
        );

        // Test max
        final maxCount = await _getCount(
          categoryId,
          _buildRangeFilter(filter.id, maxValue: '1000000'),
          token,
        );
        filterResult.tests['max'] = _TestResult(
          name: 'max ≤ 1000000',
          count: maxCount,
        );
      } else if (filter.values.isNotEmpty) {
        // Test first 3 values
        final testCount = [3, filter.values.length].reduce((a, b) => a < b ? a : b);
        for (int i = 0; i < testCount; i++) {
          final value = filter.values[i];
          final count = await _getCount(
            categoryId,
            _buildValueFilter(filter.id, value.id),
            token,
          );
          filterResult.tests['val_${value.id}'] = _TestResult(
            name: value.value,
            count: count,
            valueId: value.id,
          );
        }
      }

      result.filterResults[filter.id] = filterResult;
      print('  ✓ ${filter.id}: ${filter.title}');
    } catch (e) {
      print('  ✗ ${filter.id}: Error - $e');
    }
  }

  static Future<int> _getCount(
    int categoryId,
    Map<String, dynamic> filters,
    String? token,
  ) async {
    try {
      final response = await ApiService.getAdverts(
        categoryId: categoryId,
        filters: filters,
        limit: 100,
        token: token,
      );
      return response.data.length;
    } catch (e) {
      print('    Error: $e');
      return -1;
    }
  }

  static Map<String, dynamic> _buildRangeFilter(
    int attrId, {
    String? minValue,
    String? maxValue,
  }) {
    return {
      'values': {
        attrId.toString(): {
          if (minValue != null) 'min': minValue,
          if (maxValue != null) 'max': maxValue,
        },
      },
    };
  }

  static Map<String, dynamic> _buildValueFilter(int attrId, int valueId) {
    return {
      'value_selected': {
        attrId.toString(): [valueId],
      },
    };
  }
}
