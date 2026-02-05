import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('🧪 Testing Attribute 1048 (Вам предложат цену) - INSIDE attributes');
  print('═══════════════════════════════════════════════════════════\n');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9',
  };

  // ✅ CORRECT FORMAT: attribute_1048 INSIDE attributes.values
  final correctPayload = {
    'name': 'Тестовая квартира для проверки 1048 INSIDE',
    'description':
        'Это просторная и светлая однокомнатная квартира, расположенная в удобном районе. Идеально подходит для молодой семьи.',
    'price': '120000',
    'category_id': 2,
    'region_id': 1,
    'address': {'region_id': 13, 'city_id': 70, 'street_id': 9199},
    'contacts': {'user_phone_id': 21, 'user_email_id': 18},

    'attributes': {
      'value_selected': [
        42, // Attribute 6 - 3 комнаты
        174, // Attribute 19 - Частное лицо
      ],
      'values': {
        '1040': {'value': 4, 'max_value': 5},
        '1127': {'value': 50, 'max_value': 100},
        '1048': true, // ✅ ATTRIBUTE 1048 INSIDE attributes.values!
      },
    },
    'is_auto_renew': false,
  };

  print('📋 Payload structure:');
  print('   • attributes.values[1048] = true: ✅');
  print('   • attributes.value_selected: ✅');
  print('   • attributes.values[1040], [1127]: ✅');
  print('\n📤 Sending request...\n');

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(correctPayload),
    );

    print('Status: ${response.statusCode}');

    final utf8Response = utf8.decode(response.bodyBytes);
    final data = jsonDecode(utf8Response);

    print('Response: ${jsonEncode(data)}\n');

    if (response.statusCode == 201 || response.statusCode == 200) {
      print('✅ SUCCESS! Advert created!');
      print('   Message: ${data['message']}');
      if (data['data'] != null && data['data']['id'] != null) {
        print('   Advert ID: ${data['data']['id']}');
      }
    } else if (response.statusCode == 422) {
      print('❌ VALIDATION ERROR (422)');
      print('   Message: ${data['message']}');
      if (data['errors'] != null) {
        print('   Detailed errors:');
        (data['errors'] as Map).forEach((key, value) {
          print('      • $key: $value');
        });
      }
    } else {
      print('❌ ERROR: ${response.statusCode}');
      print('   Message: ${data['message']}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
