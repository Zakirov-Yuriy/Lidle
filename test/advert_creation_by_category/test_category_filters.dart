// Quick test to check valid VALUE IDs for category 2
// Run with: dart test_category_filters.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

const String apiBaseUrl = 'https://dev-api.lidle.io/v1';
const String token =
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI5MzU1NiwiZXhwIjoxNzcwMjk3MTU2LCJuYmYiOjE3NzAyOTM1NTYsImp0aSI6ImlhS09Kd3BFRlBtcjJwcWgiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.HVyqbB5a5dIHzvHU3fOdm8XvgBUdXaEV8dXJSglx2do';

void main() async {
  print('🔍 Testing category 2 filters...\n');

  try {
    // Get all filters for category 2
    final url = Uri.parse('$apiBaseUrl/content/meta/filters?category_id=2');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final filters = data['data']['filters'] as List;

        print('✅ Found ${filters.length} filters for category 2:\n');

        // Create a map of VALUE IDs to their filter info
        final valueIdMap = <int, Map<String, dynamic>>{};

        for (final filter in filters) {
          final filterId = filter['id'];
          final filterTitle = filter['title'];
          final values = filter['values'] as List?;

          print('📋 Filter ID=$filterId: "$filterTitle"');
          print('   is_multiple: ${filter['is_multiple']}');
          print('   is_range: ${filter['is_range']}');
          print('   data_type: ${filter['data_type']}');

          if (values != null && values.isNotEmpty) {
            print('   Values (${values.length}):');
            for (final val in values) {
              final valueId = val['id'];
              final valueName = val['value'];
              valueIdMap[valueId] = {
                'filter_id': filterId,
                'filter_title': filterTitle,
                'value_name': valueName,
              };
              print('      - ID=$valueId: "$valueName"');
            }
          }
          print('');
        }

        // Check which of our test VALUE IDs are valid
        print('\n🔍 CHECKING OUR TEST VALUE IDS:\n');
        final testValueIds = [42, 140, 174, 103, 1048];

        for (final id in testValueIds) {
          if (valueIdMap.containsKey(id)) {
            final info = valueIdMap[id]!;
            print('✅ VALUE ID $id IS VALID');
            print(
              '   Filter: ${info['filter_title']} (ID=${info['filter_id']})',
            );
            print('   Value name: ${info['value_name']}');
          } else {
            print('❌ VALUE ID $id IS INVALID for category 2');
          }
          print('');
        }
      } else {
        print('❌ Unexpected response structure');
        print('Response: $data');
      }
    } else {
      print('❌ API Error: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
