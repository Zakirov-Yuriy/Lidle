import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('📋 /adverts/create для категории 2\n');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
  };

  try {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/adverts/create',
      ).replace(queryParameters: {'category_id': '2'}),
      headers: headers,
    );

    final data = jsonDecode(response.body);
    print(jsonEncode(data));
  } catch (e) {
    print('❌ Error: $e');
  }
}
