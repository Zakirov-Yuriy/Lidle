import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  // Попытка создания объявления с правильными value_ids
  final createAdvertRequest = {
    'name': 'Просторная квартира',
    'description':
        'Это просторная и светлая однокомнатная квартира, расположенная в удобном районе.',
    'price': '120000',
    'category_id': 2,
    'region_id': 1, // main_region.id
    'is_auto_renew': false,
    'address': {
      'region_id': 13, // sub-region (region.id)
      'city_id': 70,
      'street_id': 9199,
    },
    'attributes': {
      'value_selected': [
        42, // Attribute 6 (Rooms) = 3 rooms
        174, // Attribute 19 (Business/Individual) = Private
        100, // Attribute 1048 (Price offer)
        // Попробуем без 1127 и 100, возможно нужны другие value_ids
      ],
      'values': {
        '1040': {
          // Attribute 1040 (Floor/Area)
          'value': 4,
          'max_value': 5,
        },
      },
    },
    'contacts': {
      'user_phone_id': 21, // Phone ID from /me/settings/phones
      'user_email_id': 18, // Email ID from /me/settings/emails
    },
  };

  print('🔍 Тестирование создания объявления');
  print('═══════════════════════════════════════════════════════');
  print('📋 Request (краткий вывод):');
  print(jsonEncode(createAdvertRequest));
  print('═══════════════════════════════════════════════════════');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(createAdvertRequest),
    );

    print('Status: ${response.statusCode}');

    if (response.statusCode != 201 && response.statusCode != 200) {
      print('\n❌ Ошибка создания объявления');
      final Map<String, dynamic> data = jsonDecode(response.body);

      print('Message: ${data['message']}');

      if (data['errors'] != null && data['errors'] is Map) {
        print('\n🔴 Ошибки валидации:');
        (data['errors'] as Map).forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            print('  • $key: ${value.join(', ')}');
          } else {
            print('  • $key: $value');
          }
        });
      }
    } else {
      print('\n✅ Успешно! Объявление создано');
      final Map<String, dynamic> data = jsonDecode(response.body);
      print('Message: ${data['message']}');
    }
  } catch (e) {
    print('❌ Ошибка: $e');
  }
}
