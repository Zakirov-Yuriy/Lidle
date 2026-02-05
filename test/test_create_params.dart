import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('🔍 Getting create adverts parameters for category 2...');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/adverts/create?category_id=2'),
      headers: headers,
    );

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      print('\n📋 Full response:');
      print(jsonEncode(data));

      if (data['data'] != null && (data['data'] as Map)['filters'] != null) {
        final filters = (data['data'] as Map)['filters'] as List;

        print('\n\n📊 All required attributes:');
        for (final attr in filters) {
          final id = attr['id'];
          final title = attr['title'];
          final required = attr['is_required'] ?? false;

          if (required) {
            print('  ⭐ ID=$id, Title="$title" (REQUIRED)');
            if (attr['values'] != null && (attr['values'] as List).isNotEmpty) {
              final values = attr['values'] as List;
              for (final val in values.take(3)) {
                print('     - value_id=${val['id']}, value="${val['value']}"');
              }
            }
          }
        }
      }
    } else {
      print('Error: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
