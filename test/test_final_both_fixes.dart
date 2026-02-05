import 'package:http/http.dart' as http;
import 'dart:convert';

/// Final verification test for both fixes:
/// 1. Attribute 1048 inside attributes.values
/// 2. Attribute 1127 (Total area) inside attributes.values
void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('🧪 FINAL VERIFICATION TEST');
  print('═══════════════════════════════════════════════════════════');
  print('Testing both fixes:');
  print('  1. Attribute 1048 (Вам предложат цену) INSIDE attributes');
  print('  2. Attribute 1127 (Общая площадь) INSIDE attributes');
  print('═══════════════════════════════════════════════════════════\n');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9',
  };

  // ✅ CORRECT PAYLOAD with both fixes
  final payload = {
    'name': 'Финальная проверка - оба исправления',
    'description':
        'Это просторная и светлая однокомнатная квартира, расположенная в удобном районе. Идеально подходит для молодой семьи или одного человека.',
    'price': '150000',
    'category_id': 2,
    'region_id': 1,
    'address': {'region_id': 13, 'city_id': 70, 'street_id': 9199},
    'contacts': {'user_phone_id': 21, 'user_email_id': 18},

    'attributes': {
      'value_selected': [
        42, // Attribute 6 - Quantity rooms
        174, // Attribute 19 - Private person
      ],
      'values': {
        // Range attributes
        '1040': {'value': 4, 'max_value': 5}, // Floor
        '1127': {'value': 50, 'max_value': 100}, // ✅ Total area INSIDE
        // Boolean attribute
        '1048': true, // ✅ Price offer INSIDE attributes!
      },
    },
    'is_auto_renew': false,
  };

  print('📋 Payload verification:');
  print(
    '   ✅ attributes.values["1048"] = ${payload['attributes']['values']['1048']}',
  );
  print(
    '   ✅ attributes.values["1127"] = ${payload['attributes']['values']['1127']}',
  );
  print(
    '   ✅ attributes.values["1040"] = ${payload['attributes']['values']['1040']}',
  );
  print(
    '   ✅ attributes.value_selected = ${payload['attributes']['value_selected']}',
  );
  print('\n📤 Sending request to API...\n');

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload),
    );

    print('════════════════════════════════════════════════════════');
    print('Status: ${response.statusCode}');

    final utf8Response = utf8.decode(response.bodyBytes);
    final data = jsonDecode(utf8Response);

    print('Response: ${jsonEncode(data)}');
    print('════════════════════════════════════════════════════════\n');

    if (response.statusCode == 201) {
      print('✅✅✅ SUCCESS! Both fixes work correctly!');
      print('   Message: ${data['message']}');
      if (data['data'] != null && data['data']['id'] != null) {
        print('   Created Advert ID: ${data['data']['id']}');
      }
    } else if (response.statusCode == 422) {
      print('❌ Validation Error (422)');
      print('   Message: ${data['message']}');
      if (data['errors'] != null) {
        print('   Validation errors:');
        (data['errors'] as Map).forEach((key, value) {
          print('      • $key: $value');
        });

        // Detailed analysis
        print('\n🔍 Error Analysis:');
        if (data['errors'].containsKey('attributes')) {
          print('   ❌ Issue: attributes field has errors');
          print('   Check: Both 1048 and 1127 should be in attributes.values');
        }
      }
    } else {
      print('❌ Error ${response.statusCode}');
      print('   Message: ${data['message']}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
