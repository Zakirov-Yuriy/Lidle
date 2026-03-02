import 'dart:io';
import 'dart:convert';

void main() async {
  const baseUrl = 'https://dev-api.lidle.io/v1';

  // Получите токен из логов или из переменной окружения
  const token = 'YOUR_TOKEN_HERE';

  print('═══════════════════════════════════════════════════════════');
  print('🧪 ТЕСТ: Проверка фильтрации по Ландшафту (ID=18, Value=154)');
  print('═══════════════════════════════════════════════════════════\n');

  // ШАГ 1: Получить объявления БЕЗ фильтра
  print('📍 ШАГ 1: Получить объявления БЕЗ фильтра');
  print('─────────────────────────────────────────────────────────────');

  var response = await httpGet(
    '$baseUrl/adverts?category_id=2&limit=10',
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final count = (data['data'] as List?)?.length ?? 0;
    print('✅ Получено $count объявлений БЕЗ фильтра\n');

    // Выведем ID и структуру первого объявления
    if (count > 0) {
      final first = (data['data'] as List)[0] as Map<String, dynamic>;
      print('📋 Первое объявление:');
      print('   ID: ${first['id']}');
      print('   Title: ${first['name']}');
      print('   Attributes type: ${first['attributes']?.runtimeType}');

      if (first['attributes'] != null) {
        print(
          '   Attributes keys: ${(first['attributes'] as Map).keys.toList()}',
        );

        // Проверим структуру attributes
        final attrs = first['attributes'];
        if (attrs is Map) {
          if (attrs['value_selected'] != null) {
            print('\n   ✅ Найден ключ value_selected:');
            print('      ${attrs['value_selected']}');
          }
          if (attrs['values'] != null) {
            print('\n   ✅ Найден ключ values:');
            print(
              '      Keys: ${(attrs['values'] as Map).keys.take(5).toList()}',
            );
          }
        }
      }
    }
  } else {
    print('❌ Ошибка: ${response.statusCode}\n');
  }

  // ШАГ 2: Попробуем фильтр по ландшафту
  print('\n───────────────────────────────────────────────────────────── ');
  print('📍 ШАГ 2: Получить объявления С ФИЛЬТРОМ ландшафта');
  print('   Формат: filters[value_selected][18][0]=154');
  print('─────────────────────────────────────────────────────────────');

  response = await httpGet(
    '$baseUrl/adverts?category_id=2&filters[value_selected][18][0]=154&limit=10',
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final count = (data['data'] as List?)?.length ?? 0;
    print('✅ Получено $count объявлений С ФИЛЬТРОМ\n');
  } else {
    print('❌ Ошибка: ${response.statusCode}\n');
  }

  // ШАГ 3: Попробуем альтернативный формат
  print('───────────────────────────────────────────────────────────── ');
  print('📍 ШАГ 3: Альтернативный формат фильтра');
  print('   Формат: filters[value_selected][18]=154');
  print('─────────────────────────────────────────────────────────────');

  response = await httpGet(
    '$baseUrl/adverts?category_id=2&filters[value_selected][18]=154&limit=10',
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final count = (data['data'] as List?)?.length ?? 0;
    print('✅ Получено $count объявлений\n');
  } else {
    print('❌ Ошибка: ${response.statusCode}\n');
  }

  // ШАГ 4: Проверим какие фильтры вообще поддерживает API
  print('───────────────────────────────────────────────────────────── ');
  print('📍 ШАГ 4: Попробуем доступные фильтры');
  print('─────────────────────────────────────────────────────────────');

  // Получим объявление с фильтром по ID дома
  response = await httpGet(
    '$baseUrl/adverts?category_id=2&filters[value_selected][1][0]=1&limit=10',
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final count = (data['data'] as List?)?.length ?? 0;
    print('✅ Фильтр по Тип дома (ID=1, Value=1): $count объявлений\n');
  }

  print('═══════════════════════════════════════════════════════════');
  print('Тестирование завершено');
  print('═══════════════════════════════════════════════════════════');
}

Future<HttpResponse> httpGet(String url, {Map<String, String>? headers}) async {
  final uri = Uri.parse(url);
  final client = HttpClient();

  try {
    final request = await client.getUrl(uri);

    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
    }

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    return HttpResponse(response.statusCode, body);
  } catch (e) {
    print('Error: $e');
    return HttpResponse(0, '');
  }
}

class HttpResponse {
  final int statusCode;
  final String body;

  HttpResponse(this.statusCode, this.body);
}
