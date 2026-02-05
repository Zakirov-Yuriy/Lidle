import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('🔍 Fetching advert ID 26 to check its structure...');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/adverts/26'),
      headers: headers,
    );

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      print('\n✅ Advert structure:');
      print(jsonEncode(data));

      if (data['data'] != null) {
        final advert = data['data'] as Map<String, dynamic>;
        print('\n📋 Key fields:');
        print('  name: ${advert['name']}');
        print('  region_id: ${advert['region_id']}');
        print('  address: ${advert['address']}');
        print('  category_id: ${advert['category_id']}');
      }
    } else {
      print('Error: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
