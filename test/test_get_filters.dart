import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('🔍 Getting filters for category 2...');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/meta/filters?category_id=2'),
      headers: headers,
    );

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['data'] != null && (data['data'] as Map).isNotEmpty) {
        final filters = (data['data'] as Map);

        if (filters['filters'] != null) {
          final filterList = filters['filters'] as List;

          // Find attributes 6, 19, 105
          for (final attr in filterList) {
            final id = attr['id'];
            final title = attr['title'];

            if ([6, 19, 105].contains(id)) {
              print('\n📋 Attribute ID=$id, Title="$title"');
              if (attr['values'] != null &&
                  (attr['values'] as List).isNotEmpty) {
                final values = attr['values'] as List;
                for (final val in values.take(5)) {
                  // First 5 values
                  print('  - value_id=${val['id']}, value="${val['value']}"');
                }
                if (values.length > 5) {
                  print('  ... and ${values.length - 5} more');
                }
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
