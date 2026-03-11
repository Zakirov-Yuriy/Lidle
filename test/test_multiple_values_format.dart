import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('\n' + '='*80);
  print('🧪 TEST: КАК ОТПРАВИТЬ НЕСКОЛЬКО ЗНАЧЕНИЙ ДЛЯ ОДНОГО ФИЛЬТРА?');
  print('='*80);

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  // Попытка 1: Один параметр с одним значением (РАБОТАЕТ)
  print('\n[ПОПЫТКА 1] Один параметр - одно значение');
  print('URL: $baseUrl/adverts?category_id=2&filters[value_selected][6]=40&limit=3');
  var resp = await http.get(
    Uri.parse('$baseUrl/adverts?category_id=2&filters[value_selected][6]=40&limit=3'),
    headers: headers,
  );
  print('Status: ${resp.statusCode} ✅');
  if (resp.statusCode == 200) {
    final count = ((jsonDecode(resp.body)['data'] as List?) ?? []).length;
    print('Results: $count');
  }

  // Попытка 2: Два параметра с теми же именами (последний вернет только 41?)
  print('\n[ПОПЫТКА 2] Два параметра с одинаковыми именами (последнее значение победит?)');
  var url2 = Uri.parse(
    '$baseUrl/adverts?category_id=2&filters[value_selected][6]=40&filters[value_selected][6]=41&limit=3',
  );
  print('URL: ${url2.toString()}');
  resp = await http.get(url2, headers: headers);
  print('Status: ${resp.statusCode}');
  if (resp.statusCode == 200) {
    final count = ((jsonDecode(resp.body)['data'] as List?) ?? []).length;
    print('Results: $count (нужна проверка это результаты для 40, 41, или только 41?)');
  }

  // Попытка 3: С индексом для множественного выбора
  print('\n[ПОПЫТКА 3] Индексированный формат');
  var url3 = Uri.parse(
    '$baseUrl/adverts?category_id=2&filters[value_selected][6][0]=40&filters[value_selected][6][1]=41&limit=3',
  );
  print('URL: ${url3.toString()}');
  resp = await http.get(url3, headers: headers);
  print('Status: ${resp.statusCode}');
  if (resp.statusCode == 200) {
    final count = ((jsonDecode(resp.body)['data'] as List?) ?? []).length;
    print('Results: $count');
  } else {
    final data = jsonDecode(resp.body);
    print('Error: ${data['message']}');
  }

  // Попытка 4: Через attributes с индексом
  print('\n[ПОПЫТКА 4] attributes с индексом');
  var url4 = Uri.parse(
    '$baseUrl/adverts?category_id=2&attributes[6][0]=40&attributes[6][1]=41&limit=3',
  );
  print('URL: ${url4.toString()}');
  resp = await http.get(url4, headers: headers);
  print('Status: ${resp.statusCode}');
  if (resp.statusCode == 200) {
    final count = ((jsonDecode(resp.body)['data'] as List?) ?? []).length;
    print('Results: $count');
  }

  // Попытка 5: Запятая-разделенные значения
  print('\n[ПОПЫТКА 5] Запятая-разделенные значения');
  var url5 = Uri.parse(
    '$baseUrl/adverts?category_id=2&filters[value_selected][6]=40,41&limit=3',
  );
  print('URL: ${url5.toString()}');
  resp = await http.get(url5, headers: headers);
  print('Status: ${resp.statusCode}');
  if (resp.statusCode == 200) {
    final count = ((jsonDecode(resp.body)['data'] as List?) ?? []).length;
    print('Results: $count');
  }
}
