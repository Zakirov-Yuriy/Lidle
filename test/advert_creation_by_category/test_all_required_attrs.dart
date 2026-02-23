import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('📋 Получение параметров для создания объявления категория 2');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/adverts/create',
      ).replace(queryParameters: {'category_id': '2'}),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['data'] != null) {
        final attrs = (data['data'] is List)
            ? (data['data'] as List)
            : ((data['data']['filters'] ?? []) as List);

        print('\n✅ Все обязательные атрибуты:');
        for (final attr in attrs) {
          final id = attr['id'];
          final title = attr['title'];
          final required = attr['required'] ?? false;
          final values = attr['values'] ?? [];

          if (required) {
            print('\n🔴 ОБЯЗАТЕЛЬНЫЙ - ID=$id: $title');
            print('   is_multiple: ${attr['is_multiple']}');
            print('   Значения (${values.length}):');

            for (final val in values) {
              print('     - ID=${val['id']}: ${val['value']}');
            }
          }
        }

        print('\n\n📊 ВСЕ атрибуты для информации:');
        for (final attr in attrs) {
          final id = attr['id'];
          final title = attr['title'];
          final required = attr['required'] ?? false;
          final values = attr['values'] ?? [];

          print(
            '\nID=$id ($title) - Required=$required, Multiple=${attr['is_multiple']}, Values=${values.length}',
          );
        }
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
