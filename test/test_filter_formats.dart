import 'dart:convert';
import 'package:http/http.dart' as http;

/// Тестируем разные форматы фильтров чтобы найти правильный

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('🧪 ТЕСТИРОВАНИЕ РАЗНЫХ ФОРМАТОВ ФИЛЬТРОВ');
  print('═══════════════════════════════════════════════════════════\n');

  const baseUrl = 'https://dev-api.lidle.io/v1';
  const headers = {
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'X-Client-Platform': 'web',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  // Разные варианты фильтров для тестирования
  final filterVariants = [
    {
      'name': 'Вариант 1: filters[value_selected][18][0]=154',
      'url':
          '$baseUrl/adverts?category_id=2&filters[value_selected][18][0]=154',
    },
    {
      'name': 'Вариант 2: filters[values][18][0]=154',
      'url': '$baseUrl/adverts?category_id=2&filters[values][18][0]=154',
    },
    {
      'name': 'Вариант 3: filters[attributes][18][0]=154',
      'url': '$baseUrl/adverts?category_id=2&filters[attributes][18][0]=154',
    },
    {
      'name': 'Вариант 4: attributes[18][0]=154',
      'url': '$baseUrl/adverts?category_id=2&attributes[18][0]=154',
    },
    {
      'name': 'Вариант 5: filter[18]=154',
      'url': '$baseUrl/adverts?category_id=2&filter[18]=154',
    },
    {
      'name': 'Вариант 6: attribute_18=154',
      'url': '$baseUrl/adverts?category_id=2&attribute_18=154',
    },
    {
      'name': 'Вариант 7: attr[18]=154',
      'url': '$baseUrl/adverts?category_id=2&attr[18]=154',
    },
    {
      'name': 'Вариант 8: filters[18]=154',
      'url': '$baseUrl/adverts?category_id=2&filters[18]=154',
    },
    {
      'name': 'Вариант 9: value_selected[18]=154',
      'url': '$baseUrl/adverts?category_id=2&value_selected[18]=154',
    },
    {
      'name': 'Вариант 10: values_id[18]=154',
      'url': '$baseUrl/adverts?category_id=2&values_id[18]=154',
    },
  ];

  for (final variant in filterVariants) {
    print('📌 ${variant['name']}');
    print('   URL: ${variant['url']}');

    try {
      final response = await http.get(
        Uri.parse(variant['url']!),
        headers: headers,
      );

      print('   Статус: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final adverts = data['data'] as List;
        print('   ✅ УСПЕХ! Найдено ${adverts.length} объявлений');

        if (adverts.isNotEmpty) {
          final found80 = adverts.any((a) => a['id'] == 80 || a['id'] == '80');
          if (found80) {
            print('   🎉 ОБЪЯВЛЕНИЕ #80 НАЙДЕНО!!!');
          } else {
            print('   ℹ️  Объявление 80 НЕ в результатах');
          }
        }
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('   ❌ 422 - Ошибка валидации');
        print('      Сообщение: ${data['message']}');
        if (data['errors'] is Map) {
          (data['errors'] as Map).forEach((key, value) {
            print('      $key: $value');
          });
        }
      } else {
        print('   ❌ Ошибка ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Исключение: $e');
    }

    print('');
  }

  print('═' * 60);
}
