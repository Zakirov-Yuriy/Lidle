import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  String? token;

  print('');
  print('═══════════════════════════════════════════════════════════');
  print('🔍 ПОЛНЫЙ ПОИСК: ВСЕ города ДНР (включая Мариуполь)');
  print('═══════════════════════════════════════════════════════════');
  print('');

  try {
    print('📍 Загружаем список регионов...\n');

    final regionsUri = Uri.parse('$baseUrl/addresses/regions');
    final regionsResponse = await http
        .get(regionsUri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));

    if (regionsResponse.statusCode != 200) {
      print('❌ Ошибка: ${regionsResponse.statusCode}');
      return;
    }

    final regionsData = jsonDecode(regionsResponse.body) as Map<String, dynamic>;
    final regionsList = regionsData['data'] as List<dynamic>? ?? [];

    print('✅ Загружено: ${regionsList.length} регионов\n');

    // Найти ДНР
    Map<String, dynamic>? dnrRegion;
    for (final region in regionsList) {
      final name = region['name'] as String? ?? '';
      if (name.toLowerCase().contains('донец')) {
        dnrRegion = region as Map<String, dynamic>;
      }
    }

    if (dnrRegion == null) {
      print('❌ ДНР не найдена!');
      return;
    }

    final dnrId = dnrRegion['id'] as int? ?? 0;
    print('✅ Найдена: ДНР (ID: $dnrId)\n');

    // Загрузить города
    print('🏙️  Загружаем города (полный поиск со всеми запросами)...\n');

    final allCities = <int, Map<String, dynamic>>{};

    // Расширенный список поисков
    final searches = [
      // Основные поиски
      'Донецкая Народная',
      'Донец',
      'город',
      'село',
      'пгт',
      'поселок',
      // Специфические города
      'Мариуполь',
      'Марьинка',
      'Красногоровка',
      'Моспино',
      // Дополнительные варианты
      'Луган',
      'Кремен',
      'Азов',
      'Шахт',
      'Макие',
      'Ясно',
      'Свято',
      'Новый',
      'Старый',
      'Гор',
      'Вод',
      'Окт',
      'Паул',
      'Грин',
      'Спарт',
    ];

    int totalSearch = 0;
    for (int i = 0; i < searches.length; i++) {
      final query = searches[i];
      print(
        '📌 Поиск ${(i + 1).toString().padLeft(2)}/${searches.length}: "$query"...',
      );
      final count = await searchAndAdd(baseUrl, query, allCities, token);
      totalSearch += count;
      if (count > 0) {
        print('   ✅ Найдено: $count, всего: ${allCities.length}');
      } else {
        print('   - Ничего не найдено');
      }
    }

    print('\n═══════════════════════════════════════════════════════════');
    print('📊 РЕЗУЛЬТАТЫ');
    print('═══════════════════════════════════════════════════════════\n');

    if (allCities.isEmpty) {
      print('⚠️  Города не найдены!\n');
      return;
    }

    // Сортировка по имени
    final sortedCities = allCities.values.toList();
    sortedCities.sort((a, b) {
      final nameA = (a['name'] as String?) ?? '';
      final nameB = (b['name'] as String?) ?? '';
      return nameA.compareTo(nameB);
    });

    // Вывод списка с номерами
    print('Все города ДНР (${sortedCities.length} шт.):\n');
    for (int i = 0; i < sortedCities.length; i++) {
      final city = sortedCities[i];
      final name = city['name'] as String? ?? '';
      final id = city['id'] as int? ?? 0;
      print('${(i + 1).toString().padLeft(3)}. $name (ID: $id)');
    }

    print('\n═══════════════════════════════════════════════════════════');
    print('✅ ИТОГО: ${allCities.length} ГОРОДОВ ДНР');
    print('═══════════════════════════════════════════════════════════\n');

    // Проверка Мариуполя
    bool hasMariupol = allCities.values
        .any((c) => (c['name'] as String).toLowerCase().contains('мариуполь'));
    if (hasMariupol) {
      print('✅ Мариуполь НАЙДЕН в списке\n');
    } else {
      print('❌ Мариуполь НЕ НАЙДЕН в списке\n');
    }

    // Финальный Dart код
    print('📋 Готовый Dart код для проекта:\n');
    print('const List<String> dnrCities = [');
    for (int i = 0; i < sortedCities.length; i++) {
      final city = sortedCities[i];
      final name = city['name'] as String? ?? '';
      final comma = i < sortedCities.length - 1 ? ',' : '';
      print("  '$name'$comma");
    }
    print('];');
    print('\n');
  } catch (e) {
    print('❌ ОШИБКА: $e');
  }
}

/// Поиск городов по запросу
Future<int> searchAndAdd(
  String baseUrl,
  String query,
  Map<int, Map<String, dynamic>> cities,
  String? token,
) async {
  try {
    var uri = Uri.parse('$baseUrl/addresses/search');
    uri = uri.replace(queryParameters: {
      'q': query,
      'types[]': 'city',
    });

    final headers = {
      'Accept': 'application/json',
      'X-App-Client': 'mobile',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(uri, headers: headers).timeout(
      const Duration(seconds: 15),
    );

    int addedCount = 0;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];

      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionName = mainRegion['name'] as String? ?? '';

        // Только ДНР
        if (mainRegionName.toLowerCase().contains('донец')) {
          if (cityName.isNotEmpty && cityId > 0) {
            // Используем ID как ключ для дедупликации
            if (!cities.containsKey(cityId)) {
              cities[cityId] = {
                'name': cityName,
                'id': cityId,
              };
              addedCount++;
            }
          }
        }
      }
    }

    return addedCount;
  } catch (e) {
    return 0;
  }
}
