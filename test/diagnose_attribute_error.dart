import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Используем свежий токен из переменной окружения
  final token = Platform.environment['LIDLE_TEST_TOKEN'];
  if (token == null || token.isEmpty) {
    print('❌ ОШИБКА: Переменная окружения LIDLE_TEST_TOKEN не установлена');
    print('   Установите токен: set LIDLE_TEST_TOKEN=YOUR_TOKEN');
    exit(1);
  }

  print('═══════════════════════════════════════════════════════');
  print('🔍 ДИАГНОСТИКА: найти проблемный атрибут');
  print('═══════════════════════════════════════════════════════');
  print('Token: ${token.substring(0, 20)}...');
  print('');

  // STEP 1: Загрузить атрибуты для Jobs категории
  print('📥 Шаг 1: Загружаю атрибуты для Jobs категории (ID=23)...');
  final getAttributesUrl = Uri.parse(
    'https://api.lidle.kz/api/adverts/create?category_id=23',
  );

  final attributesResponse = await http.get(
    getAttributesUrl,
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );

  if (attributesResponse.statusCode != 200) {
    print('❌ Ошибка при загрузке атрибутов: ${attributesResponse.statusCode}');
    print('   Ответ: ${attributesResponse.body}');
    exit(1);
  }

  final attributesBody = jsonDecode(attributesResponse.body) as Map;
  final filters = attributesBody['data']?['filters'] as List?;

  if (filters == null || filters.isEmpty) {
    print('❌ Нет атрибутов в ответе');
    print('   Ответ: ${attributesResponse.body}');
    exit(1);
  }

  print('✅ Загружено ${filters.length} атрибутов');
  print('');

  // Выводим список атрибутов
  print('📋 Атрибуты Jobs категории:');
  for (int i = 0; i < filters.length; i++) {
    final filter = filters[i] as Map;
    final id = filter['id'];
    final title = filter['title'];
    print('   [$i] ID=$id: $title');
  }
  print('');

  // STEP 2: Подготовим данные для отправки
  print('📤 Шаг 2: Готовлю тестовый запрос на создание объявления...');
  print('');

  // Для каждого атрибута отправим тестовый запрос
  // Первый раз отправим с ПУСТЫМИ атрибутами

  const String testUrl = 'https://api.lidle.kz/api/adverts';

  // Тестовый запрос с минимальными данными + пустой массив атрибутов
  final testPayload1 = {
    'name': 'Тестовое объявление',
    'description': 'Тест',
    'category_id': 23,
    'region_id': 1,
    'attributes': {'value_selected': [], 'values': {}},
  };

  print('🧪 Тест 1: Отправляю с ПУСТЫМИ атрибутами');
  print('   Payload: ${jsonEncode(testPayload1)}');
  print('');

  var response1 = await http.post(
    Uri.parse(testUrl),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode(testPayload1),
  );

  print('   Status: ${response1.statusCode}');
  final body1 = jsonDecode(response1.body);

  if (response1.statusCode == 422) {
    print('   ❌ Validation error (как и ожидается):');
    if (body1['errors'] is Map) {
      (body1['errors'] as Map).forEach((key, value) {
        print('      - $key: $value');
      });
    }
  } else if (response1.statusCode == 201 || response1.statusCode == 200) {
    print('   ✅ Успешно! (неожиданно)');
  } else {
    print('   ⚠️ Неизвестный статус');
  }
  print('');
  print('   Полный ответ:');
  print('   ${jsonEncode(body1)}');
  print('');
  print('═══════════════════════════════════════════════════════');

  // Теперь попробуем добавить по одному атрибут и смотреть какой вызовет ошибку
  print('');
  print('🧪 Тест 2: Добавляю атрибуты по одному, ищу виновника');
  print('');

  for (int i = 0; i < filters.length && i < 5; i++) {
    final filter = filters[i] as Map;
    final attrId = filter['id'];
    final title = filter['title'];
    final values = filter['values'] as List?;

    print('   Атрибут $i: ID=$attrId - "$title"');

    // Подготовим значение для этого атрибута
    late Map<String, dynamic> testPayload2;

    if (values != null && values.isNotEmpty) {
      // Если есть predefined values - используем первое
      final firstValue = values.first;
      final valueId = firstValue['id'];
      testPayload2 = {
        'name': 'Тестовое объявление атр $i',
        'description': 'Тест',
        'category_id': 23,
        'region_id': 1,
        'attributes': {
          'value_selected': [valueId],
          'values': {},
        },
      };
      print('      └─ Отправляю с value_id=$valueId');
    } else {
      // Если нет predefined values - отправим булево true
      testPayload2 = {
        'name': 'Тестовое объявление атр $i',
        'description': 'Тест',
        'category_id': 23,
        'region_id': 1,
        'attributes': {
          'value_selected': [],
          'values': {attrId.toString(): true},
        },
      };
      print('      └─ Отправляю с values[$attrId]=true');
    }

    var response2 = await http.post(
      Uri.parse(testUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(testPayload2),
    );

    print('      └─ Status: ${response2.statusCode}');

    final body2 = jsonDecode(response2.body);

    if (response2.statusCode == 422) {
      print('      ❌ Validation error:');
      if (body2['errors'] is Map) {
        final errors = body2['errors'] as Map;
        errors.forEach((key, value) {
          if (key.contains('attribute')) {
            print('         🚨 НАЙДЕН ВИНОВНИК: $key → $value');
          } else {
            print('         - $key: $value');
          }
        });
      }
    } else if (response2.statusCode == 201 || response2.statusCode == 200) {
      print('      ✅ Успешно с этим атрибутом!');
    }
    print('');
  }

  print('═══════════════════════════════════════════════════════');
  print('✅ Диагностика завершена');
}
