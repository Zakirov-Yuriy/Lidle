import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('\n' + '='*80);
  print('🔍 ДИАГНОСТИКА: ПОЛНОЕ СООБЩЕНИЕ ОБ ОШИБКЕ 422');
  print('='*80);

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  // Тест с ID=6  (Количество комнат)
  print('\n[TEST] ID=6 (Количество комнат) с value_id=40 (1 комната)');
  print('-'*80);

  final url = '$baseUrl/adverts?category_id=2&filters[value_selected][6][0]=40&limit=3';
  print('URL: $url\n');

  final response = await http.get(Uri.parse(url), headers: headers);
  
  print('Status: ${response.statusCode}');
  print('Headers: ${response.headers}');
  print('\nРезультат:');
  
  try {
    final data = jsonDecode(response.body);
    print(jsonEncode(data));
    
    if (data['success'] == false) {
      print('\n❌ ERROR MESSAGE:');
      print('   ${data["message"]}');
      
      if (data['errors'] != null) {
        print('\n❌ VALIDATION ERRORS:');
        final errors = data['errors'];
        if (errors is Map) {
          errors.forEach((key, value) {
            print('   $key: $value');
          });
        }
      }
    }
  } catch (e) {
    print('Error: $e');
    print('Raw response: ${response.body}');
  }

  // Попробуем альтернативный формат
  print('\n\n' + '='*80);
  print('🔧 ПОПЫТКА 2: Альтернативный формат (без индекса [0])');
  print('='*80);

  final url2 = '$baseUrl/adverts?category_id=2&filters[value_selected][6]=40&limit=3';
  print('URL: $url2\n');

  final response2 = await http.get(Uri.parse(url2), headers: headers);
  
  print('Status: ${response2.statusCode}');

  if (response2.statusCode == 200) {
    final data = jsonDecode(response2.body);
    final count = ((data['data'] as List?) ?? []).length;
    print('✅ УСПЕХ! Получено $count объявлений');
  } else {
    try {
      final data = jsonDecode(response2.body);
      print('❌ Error: ${data['message']}');
    } catch (e) {
      print('❌ Ошибка: ${response2.statusCode}');
    }
  }

  // Попробуем еще один формат (как массив через &)
  print('\n\n' + '='*80);
  print('🔧 ПОПЫТКА 3: Формат с фильтром через attributes');
  print('='*80);

  final url3 = '$baseUrl/adverts?category_id=2&attributes[6][0]=40&limit=3';
  print('URL: $url3\n');

  final response3 = await http.get(Uri.parse(url3), headers: headers);
  
  print('Status: ${response3.statusCode}');

  if (response3.statusCode == 200) {
    final data = jsonDecode(response3.body);
    final count = ((data['data'] as List?) ?? []).length;
    print('✅ УСПЕХ! Получено $count объявлений');
  } else {
    try {
      final data = jsonDecode(response3.body);
      print('❌ Error: ${data['message']}');
    } catch (e) {
      print('❌ Ошибка: ${response3.statusCode}');
    }
  }
}
