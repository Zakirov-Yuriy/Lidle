import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('Testing advert creation with proper attribute format...\n');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  final now = DateTime.now();
  final publishedAt = now.toIso8601String();

  // Test payload with proper formats
  final payload = {
    'name': 'Test Apartment Fix',
    'description': 'Test description for apartment',
    'price': 150000,
    'category_id': 2,
    'region_id': 1,
    'address': {'region_id': 13, 'city_id': 70, 'street_id': 9199},
    'attributes': {
      '1040': 50, // Price/Area = 50 (numeric)
      '6': 42, // Room count = 3 (single value, not array!)
      '19': 174, // Private person (single value)
      '1048': true, // Price Offer = true (boolean)
      '1127': 1500, // General area = 1500 (numeric)
    },
    'contacts': {
      'user_phone_id': 1, // Assuming user has phone with ID 1
      'user_email_id': 1, // Assuming user has email with ID 1
    },
    'is_auto_renew': false,
    'published_at': publishedAt,
  };

  print('Sending payload:');
  print(jsonEncode(payload));
  print('\n');

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
      body: jsonEncode(payload),
    );

    print('Status: ${response.statusCode}');

    // Decode UTF-8 properly
    final utf8Response = utf8.decode(response.bodyBytes);
    final data = jsonDecode(utf8Response);

    print('Response: ${jsonEncode(data)}');

    if (response.statusCode == 422) {
      print('\nValidation Errors:');
      if (data['errors'] != null) {
        (data['errors'] as Map).forEach((key, value) {
          print('  $key: $value');
        });
      }
    }
  } catch (e) {
    print('Exception: $e');
  }
}
