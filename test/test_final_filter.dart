import 'dart:convert';
import 'package:http/http.dart' as http;

/// Финальный тест - проверяем что фильтр работает с НОВЫМ форматом

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('✅ ФИНАЛЬНЫЙ ТЕСТ ФИЛЬТРА С НОВЫМ ФОРМАТОМ');
  print('═══════════════════════════════════════════════════════════\n');

  const baseUrl = 'https://dev-api.lidle.io/v1';
  const headers = {
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'X-Client-Platform': 'web',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  // НОВЫЙ ПРАВИЛЬНЫЙ ФОРМАТ: attributes[] вместо filters[value_selected][]
  final filterUrl =
      '$baseUrl/adverts?category_id=2&attributes[18][0]=154&attributes[17][0]=139';

  print('🔍 Проверяем фильтры:');
  print('   Категория: 2 (Недвижимость)');
  print('   Атрибут 18 (Ландшафт): 154 (Река)');
  print('   Атрибут 17 (Инфраструктура): 139 (Достопримечательности)');
  print('');
  print('📍 URL: $filterUrl\n');

  try {
    final response = await http.get(
      Uri.parse(filterUrl),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final adverts = data['data'] as List;

      print('✅ УСПЕХ! Статус: 200 OK');
      print('📊 Найдено объявлений: ${adverts.length}');

      if (adverts.isNotEmpty) {
        print('\n📋 Результаты:');
        for (final advert in adverts) {
          final id = (advert as Map<String, dynamic>)['id'];
          final name = advert['name'];
          print('   • ID $id: $name');
        }

        final found80 = adverts.any((a) => a['id'] == 80 || a['id'] == '80');
        if (found80) {
          print('\n🎉🎉🎉 ОБЪЯВЛЕНИЕ #80 НАЙДЕНО!!!');
          print('Фильтр работает ПРАВИЛЬНО!');
        } else {
          print('\n⚠️  Объявление 80 НЕ в результатах');
          print('Может быть оно не соответствует другим фильтрам или удалено');
        }
      } else {
        print('❌ Объявлений не найдено');
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
      final data = jsonDecode(response.body);
      print('Ответ сервера: ${data['message']}');
      if (data['errors'] is Map) {
        (data['errors'] as Map).forEach((key, value) {
          print('  $key: $value');
        });
      }
    }
  } catch (e) {
    print('❌ Исключение: $e');
  }

  print('\n' + '═' * 60);
}
