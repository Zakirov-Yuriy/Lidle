import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  // Test data from the form
  final createAdvertRequest = {
    'name': 'Просторная однокомнатная квартира',
    'description':
        'Это просторная и светлая однокомнатная квартира, расположенная в удобном районе. Идеально подходит для молодой семьи или одного человека.',
    'price': '120000',
    'category_id': 2,
    'region_id': 1, // main_region.id
    'address': {
      'region_id': 13, // region.id (sub-region)
      'city_id': 70,
      'street_id': 9199,
    },
    'is_auto_renew': false,
    'attributes': {
      'value_selected': [
        42, // Attribute 6 value (Количество комнат - 3 rooms)
        174, // Attribute 19 value (Частное лицо / Бизнес - Private person)
      ],
      'values': {
        // Numeric values for range attributes
        '1040': {'value': 4, 'max_value': 5},
      },
    },
    'contacts': {'user_phone_id': 21, 'user_email_id': 18},
  };

  print('🔍 Testing advert creation with data:');
  print('═══════════════════════════════════════════════════════');
  print('📋 Request body:');
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
    print('\nResponse:');

    final Map<String, dynamic> data = jsonDecode(response.body);
    print(jsonEncode(data));

    if (response.statusCode != 201 && response.statusCode != 200) {
      print('\n❌ Error creating advert');
      if (data['errors'] != null) {
        print('\nValidation errors:');
        if (data['errors'] is Map) {
          (data['errors'] as Map).forEach((key, value) {
            print('  • $key: $value');
          });
        } else {
          print('  ${data['errors']}');
        }
      }
    } else {
      print('\n✅ Advert created successfully!');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
