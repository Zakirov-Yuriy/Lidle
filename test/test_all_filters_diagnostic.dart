/// Полная диагностика всех фильтров
/// 
/// Этот тест:
/// 1. Загружает все доступные фильтры для категории Real Estate (ID=2)
/// 2. Для каждого фильтра отправляет запрос с одним фильтром
/// 3. Логирует количество результатов для каждого фильтра
/// 4. Показывает какие фильтры работают, какие - нет
/// 
/// Результаты помогут определить:
/// - Какие фильтры вообще работают на сервере
/// - Какие значения фильтров возвращают результаты
/// - Какие не работают вообще

import 'dart:io';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/models/filter_models.dart';

const String CATEGORY_ID = '2'; // Real Estate
const String TOKEN = ''; // Заполняется пользователем или возьмется из TokenService

void main() async {
  print('═' * 100);
  print('COMPREHENSIVE FILTER DIAGNOSTIC TEST');
  print('═' * 100);

  try {
    // Step 1: Load all available filters
    print('\n[STEP 1] Loading filters from API...\n');
    final filters = await _loadFilters();
    if (filters.isEmpty) {
      print('❌ ERROR: No filters loaded!');
      exit(1);
    }
    print('✅ Loaded ${filters.length} filters');

    // Step 2: Test unfiltered results (baseline)
    print('\n[STEP 2] Getting baseline results (no filters)...\n');
    final baselineCount = await _getResultsCount(null);
    print('📊 BASELINE RESULTS: $baselineCount listings (no filters applied)');

    // Step 3: Test each filter individually
    print('\n[STEP 3] Testing each filter individually...\n');
    print('═' * 100);

    final results = <String, Map<String, dynamic>>{};

    for (final filter in filters) {
      await _testFilter(filter, baselineCount, results);
    }

    // Step 4: Generate report
    print('\n═' * 100);
    print('DIAGNOSTIC REPORT');
    print('═' * 100);
    await _generateReport(baselineCount, results);
  } catch (e) {
    print('❌ FATAL ERROR: $e');
    exit(1);
  }
}

/// Load all filters for Real Estate category
Future<List<Attribute>> _loadFilters() async {
  try {
    // First, get creation attributes which include filters
    final attrs =
        await ApiService.getAdvertCreationAttributes(categoryId: int.parse(CATEGORY_ID));

    // Filter only those marked as filters
    final filterAttrs = attrs.where((a) => a.isFilter).toList();
    filterAttrs.sort((a, b) => a.id.compareTo(b.id));

    print('Found ${filterAttrs.length} filter attributes:');

    for (final attr in filterAttrs) {
      print('\n📍 Attribute ID=${attr.id}: "${attr.title}"');
      print('   ├─ is_range: ${attr.isRange}');
      print('   ├─ is_multiple: ${attr.isMultiple}');
      print('   ├─ is_special_design: ${attr.isSpecialDesign}');
      print('   ├─ values: ${attr.values.length}');

      if (attr.values.isNotEmpty && attr.values.length <= 10) {
        for (final val in attr.values) {
          print('      └─ ID=${val.id}: "${val.value}"');
        }
      } else if (attr.values.isNotEmpty) {
        print('      └─ ... and ${attr.values.length - 5} more values');
      }
    }

    return filterAttrs;
  } catch (e) {
    print('❌ Error loading filters: $e');
    rethrow;
  }
}

/// Get count of results with optional filters
Future<int> _getResultsCount(Map<String, dynamic>? filters) async {
  try {
    final response = await ApiService.getAdverts(
      categoryId: int.parse(CATEGORY_ID),
      filters: filters,
      limit: 100,
      token: TOKEN,
    );
    return response.data.length;
  } catch (e) {
    print('   ❌ Error: $e');
    return -1;
  }
}

/// Test a single filter
Future<void> _testFilter(
  Attribute filter,
  int baselineCount,
  Map<String, Map<String, dynamic>> results,
) async {
  print('┌─ Testing: ID=${filter.id} "${filter.title}"');

  final filterResults = <String, dynamic>{
    'id': filter.id,
    'title': filter.title,
    'tests': <String, Map<String, dynamic>>{},
  };

  try {
    // For range filters
    if (filter.isRange) {
      print('│  Type: RANGE');

      // Test with min value only
      final minOnlyFilters = await _buildRangeFilter(filter, minValue: '1');
      if (minOnlyFilters != null) {
        final count = await _getResultsCount(minOnlyFilters);
        filterResults['tests']['min_only'] = {
          'count': count,
          'filter': minOnlyFilters,
        };
        print('│  ├─ Min only (≥1): $count results');
      }

      // Test with max value only
      final maxOnlyFilters = await _buildRangeFilter(filter, maxValue: '1000000');
      if (maxOnlyFilters != null) {
        final count = await _getResultsCount(maxOnlyFilters);
        filterResults['tests']['max_only'] = {
          'count': count,
          'filter': maxOnlyFilters,
        };
        print('│  ├─ Max only (≤1000000): $count results');
      }

      // Test with range
      final rangeFilters = await _buildRangeFilter(filter, minValue: '1', maxValue: '10000');
      if (rangeFilters != null) {
        final count = await _getResultsCount(rangeFilters);
        filterResults['tests']['range'] = {
          'count': count,
          'filter': rangeFilters,
        };
        print('│  └─ Range (1-10000): $count results');
      }
    }
    // For filters with predefined values
    else if (filter.values.isNotEmpty) {
      print('│  Type: PREDEFINED VALUES (${filter.values.length} options)');

      // Test first 3 values
      final testCount = filter.values.length > 3 ? 3 : filter.values.length;
      for (int i = 0; i < testCount; i++) {
        final value = filter.values[i];
        final testFilters = _buildValueFilter(filter, value);

        final count = await _getResultsCount(testFilters);
        filterResults['tests']['value_${value.id}'] = {
          'count': count,
          'value_id': value.id,
          'value_name': value.value,
          'filter': testFilters,
        };

        final status = count > 0 ? '✅' : '❌';
        print('│  ├─ $status Value "${value.value}" (ID=${value.id}): $count results');

        if (count == baselineCount) {
          print('│     ⚠️  WARNING: Same count as baseline - filter may not work!');
        }
      }

      if (filter.values.length > 3) {
        print('│  └─ ... and ${filter.values.length - 3} more values not tested');
      }
    }
    // Simple text field
    else {
      print('│  Type: TEXT FIELD');
      // Can't test easily without knowing what values exist
      print('│  └─ (Requires valid text input - skipped)');
    }
  } catch (e) {
    print('│  ❌ ERROR: $e');
    filterResults['error'] = e.toString();
  }

  print('└──\n');
  results[filter.id.toString()] = filterResults as Map<String, dynamic>;
}

/// Build filter map for range filter
Future<Map<String, dynamic>?> _buildRangeFilter(
  Attribute filter, {
  String? minValue,
  String? maxValue,
}) async {
  // For range filters, API ID >= 1000 use filters[values] structure
  final attrId = filter.id;
  final filters = <String, dynamic>{
    'values': <String, dynamic>{
      attrId.toString(): <String, dynamic>{},
    },
  };

  if (minValue != null && minValue.isNotEmpty) {
    filters['values'][attrId.toString()]['min'] = minValue;
  }
  if (maxValue != null && maxValue.isNotEmpty) {
    filters['values'][attrId.toString()]['max'] = maxValue;
  }

  return filters;
}

/// Build filter map for predefined value selector
Map<String, dynamic> _buildValueFilter(Attribute filter, Value value) {
  // For non-range filters, API ID < 1000 use filters[value_selected] structure
  return {
    'value_selected': {
      filter.id.toString(): [value.id],
    },
  };
}

/// Generate final diagnostic report
Future<void> _generateReport(
  int baselineCount,
  Map<String, Map<String, dynamic>> results,
) async {
  int totalTested = 0;
  int working = 0;
  int notWorking = 0;
  int sameAsBaseline = 0;
  int errored = 0;

  final workingFilters = <String>[];
  final brokenFilters = <String>[];
  final suspiciousFilters = <String>[];

  print('\n[RESULTS SUMMARY]');
  print('═' * 100);
  print('Baseline (no filters): $baselineCount listings\n');

  for (final entry in results.entries) {
    final filterId = entry.key;
    final filterData = entry.value;
    final filterTitle = filterData['title'] as String;
    final tests = filterData['tests'] as Map<String, dynamic>? ?? {};

    if (filterData.containsKey('error')) {
      errored++;
      brokenFilters.add('$filterId: "$filterTitle" - ERROR');
    } else if (tests.isEmpty) {
      // Text field or special case
      continue;
    } else {
      totalTested++;

      bool filterWorking = false;
      bool sameCount = false;

      for (final test in tests.values) {
        if (test is Map<String, dynamic>) {
          final count = test['count'] as int;
          if (count > 0 && count != baselineCount) {
            filterWorking = true;
          }
          if (count == baselineCount) {
            sameCount = true;
          }
        }
      }

      if (filterWorking) {
        working++;
        workingFilters.add('$filterId: "$filterTitle" ✅');
      } else if (sameCount) {
        sameAsBaseline++;
        suspiciousFilters.add('$filterId: "$filterTitle" (same count as baseline)');
      } else {
        notWorking++;
        brokenFilters.add('$filterId: "$filterTitle" ❌');
      }
    }
  }

  print('WORKING FILTERS (results different from baseline):');
  for (final f in workingFilters) {
    print('  ✅ $f');
  }

  if (brokenFilters.isNotEmpty) {
    print('\nBROKEN FILTERS (no results or error):');
    for (final f in brokenFilters) {
      print('  ❌ $f');
    }
  }

  if (suspiciousFilters.isNotEmpty) {
    print('\nSUSPICIOUS FILTERS (returned same count as baseline):');
    print('  ⚠️  These filters may not be working server-side!');
    for (final f in suspiciousFilters) {
      print('     $f');
    }
  }

  print('\n═' * 100);
  print('STATISTICS:');
  print('  Total filters tested: $totalTested');
  print('  Working: $working (${(working / totalTested * 100).toStringAsFixed(1)}%)');
  print('  Suspicious: $sameAsBaseline');
  print('  Broken: $notWorking');
  print('  Errored: $errored');
  print('═' * 100);

  print('\n[RECOMMENDATIONS]');
  if (working == totalTested) {
    print('✅ All filters are working correctly!');
  } else if (working > totalTested / 2) {
    print('⚠️  Most filters work, but some have issues.');
    print('   Check server implementation for: ${brokenFilters.join(", ")}');
  } else {
    print('❌ Server-side filtering is not working!');
    print('   None or very few filters return different result counts.');
    print('   This suggests server API is ignoring filter parameters.');
  }
}
