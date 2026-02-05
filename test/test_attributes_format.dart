import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI5MzU1NiwiZXhwIjoxNzcwMjk3MTU2LCJuYmYiOjE3NzAyOTM1NTYsImp0aSI6ImlhS09Kd3BFRlBtcjJwcWgiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.HVyqbB5a5dIHzvHU3fOdm8XvgBUdXaEV8dXJSglx2do';

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9',
  };

  // Base payload that works for everything
  final basePayload = {
    'name': 'Тест формата - вариант',
    'description':
        'Это просторная и светлая однокомнатная квартира, расположенная в удобном районе. Идеально подходит для молодой семьи или одного человека.',
    'price': '150000',
    'category_id': 2,
    'region_id': 1,
    'address': {'region_id': 5, 'city_id': 444, 'street_id': 14221},
    'contacts': {'user_phone_id': 21, 'user_email_id': 18},
    'is_auto_renew': false,
  };

  // ============ VARIANT 1: 1048 INSIDE values (as boolean) ============
  print('🧪 VARIANT 1: 1048 INSIDE attributes.values as boolean');
  print('═══════════════════════════════════════════════════════\n');

  var payload1 = {...basePayload};
  payload1['attributes'] = {
    'value_selected': [42, 140, 174, 103],
    'values': {
      '1040': {'value': 4, 'max_value': 5},
      '1039': 'Новый дом',
      '1127': {'value': 50, 'max_value': 100},
      '1048': true, // Boolean inside values
    },
  };

  print('Payload: ${jsonEncode(payload1)}\n');

  try {
    final response1 = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload1),
    );

    print('Status: ${response1.statusCode}');
    final data1 = jsonDecode(utf8.decode(response1.bodyBytes));
    print('Response: ${jsonEncode(data1)}\n\n');

    if (response1.statusCode == 201) {
      print('✅✅✅ VARIANT 1 WORKS! (201 Created)\n');
    }
  } catch (e) {
    print('❌ Error: $e\n\n');
  }

  // ============ VARIANT 2: 1048 as String "true" ============
  print('🧪 VARIANT 2: 1048 INSIDE values as string "true"');
  print('═══════════════════════════════════════════════════════\n');

  var payload2 = {...basePayload};
  payload2['attributes'] = {
    'value_selected': [42, 140, 174, 103],
    'values': {
      '1040': {'value': 4, 'max_value': 5},
      '1039': 'Новый дом',
      '1127': {'value': 50, 'max_value': 100},
      '1048': 'true', // String "true"
    },
  };

  print('Payload: ${jsonEncode(payload2)}\n');

  try {
    final response2 = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload2),
    );

    print('Status: ${response2.statusCode}');
    final data2 = jsonDecode(utf8.decode(response2.bodyBytes));
    print('Response: ${jsonEncode(data2)}\n\n');

    if (response2.statusCode == 201) {
      print('✅✅✅ VARIANT 2 WORKS! (201 Created)\n');
    }
  } catch (e) {
    print('❌ Error: $e\n\n');
  }

  // ============ VARIANT 3: 1048 as Number 1 ============
  print('🧪 VARIANT 3: 1048 INSIDE values as number 1');
  print('═══════════════════════════════════════════════════════\n');

  var payload3 = {...basePayload};
  payload3['attributes'] = {
    'value_selected': [42, 140, 174, 103],
    'values': {
      '1040': {'value': 4, 'max_value': 5},
      '1039': 'Новый дом',
      '1127': {'value': 50, 'max_value': 100},
      '1048': 1, // Number 1
    },
  };

  print('Payload: ${jsonEncode(payload3)}\n');

  try {
    final response3 = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload3),
    );

    print('Status: ${response3.statusCode}');
    final data3 = jsonDecode(utf8.decode(response3.bodyBytes));
    print('Response: ${jsonEncode(data3)}\n\n');

    if (response3.statusCode == 201) {
      print('✅✅✅ VARIANT 3 WORKS! (201 Created)\n');
    }
  } catch (e) {
    print('❌ Error: $e\n\n');
  }

  // ============ VARIANT 4: No 1048 at all ============
  print('🧪 VARIANT 4: NO 1048 in attributes');
  print('═══════════════════════════════════════════════════════\n');

  var payload4 = {...basePayload};
  payload4['attributes'] = {
    'value_selected': [42, 140, 174, 103],
    'values': {
      '1040': {'value': 4, 'max_value': 5},
      '1039': 'Новый дом',
      '1127': {'value': 50, 'max_value': 100},
      // NO 1048
    },
  };

  print('Payload: ${jsonEncode(payload4)}\n');

  try {
    final response4 = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload4),
    );

    print('Status: ${response4.statusCode}');
    final data4 = jsonDecode(utf8.decode(response4.bodyBytes));
    print('Response: ${jsonEncode(data4)}\n\n');

    if (response4.statusCode == 201) {
      print('✅✅✅ VARIANT 4 WORKS! (201 Created)\n');
    }
  } catch (e) {
    print('❌ Error: $e\n\n');
  }

  // ============ VARIANT 5: 1048 at TOP-LEVEL (outside attributes) ============
  print('🧪 VARIANT 5: 1048 at TOP-LEVEL (outside attributes)');
  print('═══════════════════════════════════════════════════════\n');

  var payload5 = {...basePayload};
  payload5['attributes'] = {
    'value_selected': [42, 140, 174, 103],
    'values': {
      '1040': {'value': 4, 'max_value': 5},
      '1039': 'Новый дом',
      '1127': {'value': 50, 'max_value': 100},
    },
  };
  payload5['attribute_1048'] = true; // At TOP-LEVEL

  print('Payload: ${jsonEncode(payload5)}\n');

  try {
    final response5 = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload5),
    );

    print('Status: ${response5.statusCode}');
    final data5 = jsonDecode(utf8.decode(response5.bodyBytes));
    print('Response: ${jsonEncode(data5)}\n\n');

    if (response5.statusCode == 201) {
      print('✅✅✅ VARIANT 5 WORKS! (201 Created)\n');
    }
  } catch (e) {
    print('❌ Error: $e\n\n');
  }

  // ============ VARIANT 6: 1048 as object with value ============
  print('🧪 VARIANT 6: 1048 as object {value: true}');
  print('═══════════════════════════════════════════════════════\n');

  var payload6 = {...basePayload};
  payload6['attributes'] = {
    'value_selected': [42, 140, 174, 103],
    'values': {
      '1040': {'value': 4, 'max_value': 5},
      '1039': 'Новый дом',
      '1127': {'value': 50, 'max_value': 100},
      '1048': {'value': true}, // Object with value key
    },
  };

  print('Payload: ${jsonEncode(payload6)}\n');

  try {
    final response6 = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload6),
    );

    print('Status: ${response6.statusCode}');
    final data6 = jsonDecode(utf8.decode(response6.bodyBytes));
    print('Response: ${jsonEncode(data6)}\n\n');

    if (response6.statusCode == 201) {
      print('✅✅✅ VARIANT 6 WORKS! (201 Created)\n');
    }
  } catch (e) {
    print('❌ Error: $e\n\n');
  }

  print('\n\n════════════════════════════════════════════════════════');
  print('🧪 TEST COMPLETE');
  print('════════════════════════════════════════════════════════\n');
}
