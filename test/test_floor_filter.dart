import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';

  // Тестовые учетные данные
  const String testEmail = 'zakco.test@gmail.com';
  const String testPassword = '123456789';

  String? token;

  // ============================================================
  // ШАГ 1: Авторизация
  // ============================================================
  print('🔐 ШАГ 1: Авторизация...');
  print('─────────────────────────────────────────────────────────────\n');

  try {
    final loginResponse = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': testEmail,
        'password': testPassword,
        'remember': true,
      }),
    );

    if (loginResponse.statusCode == 200) {
      final loginData = jsonDecode(loginResponse.body);
      token = loginData['access_token'];
      print('✅ Авторизация успешна!');
      print('   Token: ${token?.substring(0, 30)}...');
    } else {
      print('❌ Ошибка авторизации: ${loginResponse.statusCode}');
      return;
    }
  } catch (e) {
    print('❌ Исключение при авторизации: $e');
    return;
  }

  print('');

  // ============================================================
  // ШАГ 2: Получение фильтров для категории 5 (Продажа комнат)
  // ============================================================
  print('📋 ШАГ 2: Получение фильтров (category_id=5)...');
  print('─────────────────────────────────────────────────────────────\n');

  try {
    final filtersResponse = await http.post(
      Uri.parse('$baseUrl/meta/filters'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'category_id': 5}),
    );

    if (filtersResponse.statusCode == 200) {
      final filtersData = jsonDecode(filtersResponse.body);
      final filters = filtersData['data']['filters'] as List;

      // Ищем фильтр "Этаж"
      final floorFilter = filters.firstWhere(
        (f) => (f['title'] as String).toLowerCase().contains('этаж'),
        orElse: () => null,
      );

      if (floorFilter != null) {
        print('✅ Найден фильтр "Этаж":');
        print('   ID: ${floorFilter['id']}');
        print('   Title: ${floorFilter['title']}');
        print('   is_range: ${floorFilter['is_range']}');
        print('   data_type: ${floorFilter['data_type']}');
        print('   Values: ${floorFilter['values']}');
      } else {
        print('⚠️  Фильтр "Этаж" не найден!');
        print('   Доступные фильтры:');
        for (final filter in filters) {
          print('   - ${filter['id']}: ${filter['title']}');
        }
      }
    } else {
      print('❌ Ошибка получения фильтров: ${filtersResponse.statusCode}');
      print('   Body: ${filtersResponse.body}');
    }
  } catch (e) {
    print('❌ Исключение при получении фильтров: $e');
  }

  print('');

  // ============================================================
  // ШАГ 3: Получение объявлений БЕЗ фильтра
  // ============================================================
  print('📌 ШАГ 3: Получение объявлений БЕЗ фильтра (category_id=5)...');
  print('─────────────────────────────────────────────────────────────\n');

  List<Map<String, dynamic>> allAdverts = [];

  try {
    final advertsResponse = await http.get(
      Uri.parse('$baseUrl/adverts?category_id=5&limit=50&page=1'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
      },
    );

    if (advertsResponse.statusCode == 200) {
      final advertsData = jsonDecode(advertsResponse.body);
      allAdverts = List<Map<String, dynamic>>.from(advertsData['data'] ?? []);
      print('✅ Получено ${allAdverts.length} объявлений');

      // Показываем первые 2 объявления с их атрибутами
      for (
        int i = 0;
        i < (allAdverts.length > 2 ? 2 : allAdverts.length);
        i++
      ) {
        final advert = allAdverts[i];
        print('\n📍 Объявление #${i + 1}: ${advert['name']}');
        print('   ID: ${advert['id']}');

        if (advert['attributes'] != null) {
          final attrs = advert['attributes'] as List;
          print('   Attributes: ${attrs.length}');
          for (final attr in attrs) {
            print(
              '     - [${attr['id']}] ${attr['title']}: value=${attr['value']}, max_value=${attr['max_value']}',
            );
          }
        } else {
          print('   ⚠️  No attributes in this advert');
        }
      }
    } else {
      print('❌ Ошибка получения объявлений: ${advertsResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Исключение при получении объявлений: $e');
  }

  print('\n');

  // ============================================================
  // ШАГ 4: Применение фильтра по этажу (от 1 до 5)
  // ============================================================
  print('🔍 ШАГ 4: Применение фильтра по этажу (1-5)...');
  print('─────────────────────────────────────────────────────────────\n');

  // Предполагаем, что ID фильтра "Этаж" = 1131 (по аналогии с другими категориями)
  // Если нет, мы найдем правильный ID извремі тестирования

  try {
    final filterUrl =
        '$baseUrl/adverts?category_id=5&limit=50&page=1&filters[attr_1131][min]=1&filters[attr_1131][max]=5';

    print('📦 URL фильтра:');
    print('   $filterUrl\n');

    final filteredResponse = await http.get(
      Uri.parse(filterUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
      },
    );

    if (filteredResponse.statusCode == 200) {
      final filteredData = jsonDecode(filteredResponse.body);
      final filteredAdverts = List<Map<String, dynamic>>.from(
        filteredData['data'] ?? [],
      );

      print('✅ Получено ${filteredAdverts.length} объявлений с фильтром');

      if (filteredAdverts.isEmpty) {
        print('⚠️  ПРОБЛЕМА: Фильтр вернул 0 объявлений!');
        print('\n🔧 Попробуем с другими ID атрибутов:\n');

        // Попробуем с разными ID атрибутов для поиска правильного
        for (int attrId = 1120; attrId <= 1140; attrId++) {
          final testUrl =
              '$baseUrl/adverts?category_id=5&limit=10&page=1&filters[attr_$attrId][min]=1&filters[attr_$attrId][max]=5';

          final testResponse = await http.get(
            Uri.parse(testUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'X-App-Client': 'mobile',
            },
          );

          if (testResponse.statusCode == 200) {
            final testData = jsonDecode(testResponse.body);
            final testAdverts = List<Map<String, dynamic>>.from(
              testData['data'] ?? [],
            );

            if (testAdverts.isNotEmpty) {
              print('   📌 attr_$attrId: ${testAdverts.length} объявлений ✓');
            }
          }
        }
      } else {
        // Показываем первые 2 отфильтрованных объявления
        for (
          int i = 0;
          i < (filteredAdverts.length > 2 ? 2 : filteredAdverts.length);
          i++
        ) {
          final advert = filteredAdverts[i];
          print('\n📍 Объявление #${i + 1}: ${advert['name']}');
          print('   ID: ${advert['id']}');

          if (advert['attributes'] != null) {
            final attrs = advert['attributes'] as List;
            for (final attr in attrs) {
              if ((attr['title'] as String).toLowerCase().contains('этаж')) {
                print(
                  '   Floor: value=${attr['value']}, max_value=${attr['max_value']}',
                );
              }
            }
          }
        }
      }
    } else {
      print('❌ Ошибка при применении фильтра: ${filteredResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Исключение при применении фильтра: $e');
  }

  print('\n✅ Тест завершен!');
}
