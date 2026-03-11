import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('\n' + '='*80);
  print('🧪 TEST: Проверка фильтрации по 5 ПРОБЛЕМНЫМ фильтрам');
  print('='*80);

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  // Test data for each problematic filter
  final tests = [
    {
      'id': '6',
      'title': 'Количество комнат',
      'value_id': '40', // 1 room
      'value_name': '1 комната'
    },
    {
      'id': '12',
      'title': 'Бытовая техника',
      'value_id': '102', // Подогрев полов
      'value_name': 'Подогрев полов'
    },
    {
      'id': '14',
      'title': 'Комфорт',
      'value_id': '102', // Подогрев полов
      'value_name': 'Подогрев полов'
    },
    {
      'id': '17',
      'title': 'Инфраструктура',
      'value_id': '138', // Центр города
      'value_name': 'Центр города'
    },
    {
      'id': '18',
      'title': 'Ландшафт',
      'value_id': '154', // Река
      'value_name': 'Река'
    },
  ];

  for (final test in tests) {
    await _testFilter(baseUrl, token, headers, test);
  }

  print('\n' + '='*80);
  print('✅ ТЕСТИРОВАНИЕ ЗАВЕРШЕНО');
  print('='*80 + '\n');
}

Future<void> _testFilter(
  String baseUrl,
  String token,
  Map<String, String> headers,
  Map<String, String> test,
) async {
  print('\n' + '-'*80);
  print('🧪 TEST: Фильтр "${test['title']}" (ID=${test['id']}, value=${test['value_name']})');
  print('-'*80);

  int count1 = 0;
  int count2 = 0;

  // Test without filter
  print('\n  📍 Шаг 1: БЕЗ фильтра');
  var url1 = '$baseUrl/adverts?category_id=2&limit=3';
  final resp1 = await http.get(Uri.parse(url1), headers: headers);
  
  if (resp1.statusCode == 200) {
    final data = jsonDecode(resp1.body);
    count1 = ((data['data'] as List?) ?? []).length;
    print('      ✅ Получено $count1 объявлений БЕЗ фильтра');
  } else {
    print('      ❌ Ошибка: ${resp1.statusCode}');
    return;
  }

  // Test with filter
  print('\n  📍 Шаг 2: С ФИЛЬТРОМ');
  var url2 = '$baseUrl/adverts?category_id=2&filters[value_selected][${test['id']}][0]=${test['value_id']}&limit=3';
  final urlShort = url2.length > 80 ? '${url2.substring(0, 80)}...' : url2;
  print('      URL: $urlShort');

  final resp2 = await http.get(Uri.parse(url2), headers: headers);

  if (resp2.statusCode == 200) {
    final data = jsonDecode(resp2.body);
    count2 = ((data['data'] as List?) ?? []).length;
    print('      ✅ Получено $count2 объявлений С ФИЛЬТРОМ');

    if (count2 > 0) {
      print('      ✅ ФИЛЬТР РАБОТАЕТ! (results: $count1 → $count2)');
    } else if (count1 == 0) {
      print('      ⚠️  Нет результатов ни с фильтром ни без (может быть нет данных в категории)');
    } else {
      print('      ⚠️  ВОЗМОЖНАЯ ПРОБЛЕМА: Фильтр возвращает 0 результатов!');
    }
  } else {
    print('      ❌ Ошибка: ${resp2.statusCode}');
    final respShort = resp2.body.length > 80 ? '${resp2.body.substring(0, 80)}...' : resp2.body;
    print('      📱 Ответ: $respShort');
  }
}
