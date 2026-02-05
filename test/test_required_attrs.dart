import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('Testing advert creation with REQUIRED attributes only...\n');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // Get current time
  final now = DateTime.now();
  final publishedAt = now.toIso8601String();

  // Test payload with ONLY required attributes
  final payload = {
    'name': 'Test Apartment',
    'description': 'Test description',
    'price': 150000,
    'category_id': 2,
    'region_id': 1,
    'address': {'region_id': 13, 'city_id': 70, 'street_id': 9199},
    'attributes': {
      '1040': null, // Price/Area (no value needed?)
      '6': [42], // Room count = 3
      '19': [174], // Private person
      '1048': null, // Price Offer (boolean field?)
      '1127': null, // General area (numeric?)
    },
    'contacts': {},
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
    print('Response: ${response.body}');
  } catch (e) {
    print('Exception: $e');
  }
}
