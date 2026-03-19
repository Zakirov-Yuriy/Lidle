import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  
  // Попробуем получить токен из файла или переменной окружения
  String? token;
  
  print('');
  print('═══════════════════════════════════════════════════════════');
  print('🔍 ДИАГНОСТИКА: Все города ДНР в API (расширенный поиск)');
  print('═══════════════════════════════════════════════════════════');
  print('');

  try {
    // Шаг 1: Получить список регионов
    print('📍 Шаг 1: Загружаем список регионов...\n');

    final regionsUri = Uri.parse('$baseUrl/addresses/regions');
    final regionsResponse = await http
        .get(regionsUri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));

    if (regionsResponse.statusCode != 200) {
      print('❌ Ошибка загрузки регионов: ${regionsResponse.statusCode}');
      return;
    }

    final regionsData = jsonDecode(regionsResponse.body) as Map<String, dynamic>;
    final regionsList = regionsData['data'] as List<dynamic>? ?? [];

    print('✅ Загружено регионов: ${regionsList.length}\n');

    // Шаг 2: Найти ДНР
    print('🔎 Шаг 2: Ищем ДНР в списке регионов...\n');

    Map<String, dynamic>? dnrRegion;
    for (final region in regionsList) {
      final name = region['name'] as String? ?? '';
      if (name.toLowerCase().contains('донец') ||
          name.toLowerCase().contains('днр')) {
        dnrRegion = region as Map<String, dynamic>;
      }
    }

    if (dnrRegion == null) {
      print('❌ ДНР не найдена в списке регионов!');
      return;
    }

    final dnrId = dnrRegion['id'] as int? ?? 0;
    final dnrName = dnrRegion['name'] as String? ?? 'Неизвестно';
    print('✅ Найдена ДНР: "$dnrName" (ID: $dnrId)\n');

    // Шаг 3: Загрузить города несколькими методами
    print('🏙️  Шаг 3: Загружаем города для ДНР (различные методы)...\n');

    final allCities = <String, Map<String, dynamic>>{};

    // Метод 1: Поиск с пустой строкой (может вернуть все)
    print('📌 Метод 1: Поиск с минимальной строкой...');
    await _searchCitiesAndAdd(baseUrl, '   ', allCities, token);

    // Метод 2: Поиск по названию региона
    print('📌 Метод 2: Поиск по названию региона ($dnrName)...');
    await _searchCitiesAndAdd(baseUrl, dnrName, allCities, token);

    // Метод 3: Поиск по ID региона прямо в параметрах
    print('📌 Метод 3: Специальный поиск для региона ID=$dnrId...');
    await _searchCitiesByRegionId(baseUrl, dnrId, allCities, token);

    // Метод 4: Поиск по разным буквам/слогам
    print('📌 Метод 4: Поиск по различным префиксам...');
    final searchQueries = [
      'г',
      'пгт',
      'п.',
      'с.',
      'ДНР',
      'город',
      'село',
      'поселок',
    ];
    for (final query in searchQueries) {
      print('   Ищем "$query"...');
      await _searchCitiesAndAdd(baseUrl, query, allCities, token);
    }

    // Шаг 4: Проверить информацию о каждом городе через фильтр
    print('\n📌 Метод 5: Получение информации о каждом городе...');
    if (allCities.isNotEmpty) {
      for (final cityKey in allCities.keys.toList()) {
        final city = allCities[cityKey];
        final cityId = city['id'] as int? ?? 0;
        // Проверяем регион города
        await _verifyAndUpdate(baseUrl, cityId, allCities, cityKey, token);
      }
    }

    // Шаг 5: Вывести результаты
    print('\n═══════════════════════════════════════════════════════════');
    print('📊 РЕЗУЛЬТАТЫ: Все города ДНР (${allCities.length} шт.)');
    print('═══════════════════════════════════════════════════════════\n');

    if (allCities.isEmpty) {
      print('⚠️  Города не найдены!\n');
      return;
    }

    // Сортируем по имени
    final sortedCities = allCities.values.toList();
    sortedCities.sort((a, b) {
      final nameA = (a['name'] as String?) ?? '';
      final nameB = (b['name'] as String?) ?? '';
      return nameA.compareTo(nameB);
    });

    // Выводим с нумерацией
    print('Список всех городов ДНР:');
    print('');
    for (int i = 0; i < sortedCities.length; i++) {
      final city = sortedCities[i];
      final name = city['name'] as String? ?? 'Неизвестно';
      final id = city['id'] as int? ?? 0;
      final mainRegionId = city['main_region_id'] as int? ?? 0;
      print('${(i + 1).toString().padLeft(3)}. $name (ID: $id, Region: $mainRegionId)');
    }

    print('\n═══════════════════════════════════════════════════════════');
    print('✅ Всего найдено городов: ${allCities.length}');
    print('═══════════════════════════════════════════════════════════\n');

    // Вывод для кода
    print('📋 Для использования в коде (Dart const список):\n');
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
    print('   Stack: ${StackTrace.current}');
  }
}

/// Поиск городов по запросу
Future<void> _searchCitiesAndAdd(
  String baseUrl,
  String query,
  Map<String, Map<String, dynamic>> allCities,
  String? token,
) async {
  try {
    var searchUri = Uri.parse('$baseUrl/addresses/search');
    searchUri = searchUri.replace(queryParameters: {
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

    final response = await http
        .get(searchUri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];

      print('      ✅ Найдено: ${results.length}');

      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionId = mainRegion['id'] as int? ?? 0;
        final mainRegionName = mainRegion['name'] as String? ?? '';

        // Проверяем, что это ДНР
        if (mainRegionName.toLowerCase().contains('донец') ||
            mainRegionName.toLowerCase().contains('днр')) {
          if (cityName.isNotEmpty && cityId > 0) {
            final key = '$cityName-$cityId';
            if (!allCities.containsKey(key)) {
              allCities[key] = {
                'name': cityName,
                'id': cityId,
                'main_region_id': mainRegionId,
                'main_region_name': mainRegionName,
              };
            }
          }
        }
      }
    } else if (response.statusCode != 422) {
      print('      ❌ Ошибка: ${response.statusCode}');
    }
  } catch (e) {
    // Игнорируем ошибки поиска
  }
}

/// Специальный поиск по ID региона
Future<void> _searchCitiesByRegionId(
  String baseUrl,
  int regionId,
  Map<String, Map<String, dynamic>> allCities,
  String? token,
) async {
  try {
    // Пытаемся поискать с пустым запросом и фильтром
    var searchUri = Uri.parse('$baseUrl/addresses/search');
    
    final queryParams = {
      'q': 'город',
      'types[]': 'city',
    };

    searchUri = searchUri.replace(queryParameters: queryParams);

    final headers = {
      'Accept': 'application/json',
      'X-App-Client': 'mobile',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(searchUri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];

      print('      ✅ Найдено: ${results.length}');

      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionId = mainRegion['id'] as int? ?? 0;

        if (mainRegionId == regionId &&
            cityName.isNotEmpty &&
            cityId > 0) {
          final key = '$cityName-$cityId';
          if (!allCities.containsKey(key)) {
            allCities[key] = {
              'name': cityName,
              'id': cityId,
              'main_region_id': mainRegionId,
            };
          }
        }
      }
    }
  } catch (e) {
    // Игнорируем ошибки
  }
}

/// Проверка и обновление информации о городе
Future<void> _verifyAndUpdate(
  String baseUrl,
  int cityId,
  Map<String, Map<String, dynamic>> allCities,
  String cityKey,
  String? token,
) async {
  try {
    // Можно добавить дополнительную проверку через API если нужно
    // Пока просто пропускаем
  } catch (e) {
    // Игнорируем ошибки
  }
}

  try {
    // Шаг 1: Получить список регионов
    print('📍 Шаг 1: Загружаем список регионов...\n');

    final regionsUri = Uri.parse('$baseUrl/addresses/regions');
    final regionsResponse = await http
        .get(regionsUri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));

    if (regionsResponse.statusCode != 200) {
      print('❌ Ошибка загрузки регионов: ${regionsResponse.statusCode}');
      return;
    }

    final regionsData = jsonDecode(regionsResponse.body) as Map<String, dynamic>;
    final regionsList = regionsData['data'] as List<dynamic>? ?? [];

    print('✅ Загружено регионов: ${regionsList.length}\n');

    // Шаг 2: Найти ДНР
    print('🔎 Шаг 2: Ищем ДНР в списке регионов...\n');

    Map<String, dynamic>? dnrRegion;
    for (final region in regionsList) {
      final name = region['name'] as String? ?? '';
      print('   - $name');
      if (name.toLowerCase().contains('донец') ||
          name.toLowerCase().contains('днр') ||
          name.toLowerCase().contains('донецка')) {
        dnrRegion = region as Map<String, dynamic>;
        print('      ✅ НАЙДЕНА ДНР!');
      }
    }

    if (dnrRegion == null) {
      print('\n❌ ДНР не найдена в списке регионов!');
      print('Попробуем альтернативный метод поиска...\n');

      // Альтернативный метод: поиск через searchAddresses
      await _searchCitiesByQuery(baseUrl, 'Донец');
      return;
    }

    final dnrId = dnrRegion['id'] as int? ?? 0;
    final dnrName = dnrRegion['name'] as String? ?? 'Неизвестно';
    print('\n✅ Информация о ДНР:');
    print('   ID: $dnrId');
    print('   Name: $dnrName\n');

    // Шаг 3: Загрузить города для ДНР несколькими способами
    print('🏙️  Шаг 3: Загружаем города для ДНР...\n');

    final allCities = <String, Map<String, dynamic>>{};

    // Метод 1: поиск по названию региона
    print('📌 Метод 1: Поиск по названию региона ($dnrName)...');
    await _searchCitiesAndAdd(baseUrl, dnrName, allCities);

    // Метод 2: поиск по ID региона (через фильтр)
    print('\n📌 Метод 2: Поиск с фильтром по ID ДНР ($dnrId)...');
    await _searchCitiesWithFilterAndAdd(baseUrl, dnrId, allCities);

    // Метод 3: попробовать короткие поиски
    print('\n📌 Метод 3: Поиск по общим префиксам...');
    final searchQueries = ['Донец', 'Луган', 'Макие', 'Снеж', 'Шахт'];
    for (final query in searchQueries) {
      print('   Ищем "$query"...');
      await _searchCitiesAndAdd(baseUrl, query, allCities);
    }

    // Шаг 4: Вывести результаты
    print('\n═══════════════════════════════════════════════════════════');
    print('📊 РЕЗУЛЬТАТЫ: Все города ДНР (${allCities.length} шт.)');
    print('═══════════════════════════════════════════════════════════\n');

    if (allCities.isEmpty) {
      print('⚠️  Города не найдены!\n');
      return;
    }

    // Сортируем по имени
    final sortedCities = allCities.values.toList();
    sortedCities.sort((a, b) {
      final nameA = (a['name'] as String?) ?? '';
      final nameB = (b['name'] as String?) ?? '';
      return nameA.compareTo(nameB);
    });

    // Выводим с нумерацией
    for (int i = 0; i < sortedCities.length; i++) {
      final city = sortedCities[i];
      final name = city['name'] as String? ?? 'Неизвестно';
      final id = city['id'] as int? ?? 0;
      final mainRegionId = city['main_region_id'] as int? ?? 0;
      print('${(i + 1).toString().padLeft(3)}. $name (ID: $id, Region: $mainRegionId)');
    }

    print('\n═══════════════════════════════════════════════════════════');
    print('✅ Всего найдено городов: ${allCities.length}');
    print('═══════════════════════════════════════════════════════════\n');

    // Шаг 5: Анализ - скопировать список для использования в коде
    print('📋 Для использования в коде (Dart const список):\n');
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
    print('   Stack: ${StackTrace.current}');
  }
}

/// Поиск городов по запросу и добавление их в карту
Future<void> _searchCitiesAndAdd(
  String baseUrl,
  String query,
  Map<String, Map<String, dynamic>> allCities,
) async {
  try {
    // Исправлено: параметры в URL query string
    var searchUri = Uri.parse('$baseUrl/addresses/search');
    searchUri = searchUri.replace(queryParameters: {
      'q': query,
      'types[]': 'city', // types передается как массив
    });

    final response = await http
        .get(
          searchUri,
          headers: {
            'Accept': 'application/json',
            'X-App-Client': 'mobile',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];

      print('   ✅ Найдено: ${results.length}');

      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionId = mainRegion['id'] as int? ?? 0;
        final mainRegionName = mainRegion['name'] as String? ?? '';

        // Проверяем, что это ДНР
        if (mainRegionName.toLowerCase().contains('донец') ||
            mainRegionName.toLowerCase().contains('днр')) {
          if (cityName.isNotEmpty && cityId > 0) {
            final key = '$cityName-$cityId';
            allCities[key] = {
              'name': cityName,
              'id': cityId,
              'main_region_id': mainRegionId,
              'main_region_name': mainRegionName,
            };
          }
        }
      }
    } else {
      print('   ❌ Ошибка: ${response.statusCode}');
      print('   📝 Response: ${response.body}');
    }
  } catch (e) {
    print('   ❌ Исключение: $e');
  }
}

/// Поиск городов с фильтром по ID региона
Future<void> _searchCitiesWithFilterAndAdd(
  String baseUrl,
  int regionId,
  Map<String, Map<String, dynamic>> allCities,
) async {
  try {
    // Параметры в query string
    var searchUri = Uri.parse('$baseUrl/addresses/search');
    searchUri = searchUri.replace(queryParameters: {
      'q': '   ', // Минимум 3 символа
      'types[]': 'city',
      'filters[main_region_id]': regionId.toString(),
    });

    final response = await http.get(
      searchUri,
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];

      print('   ✅ Найдено: ${results.length}');

      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionId = mainRegion['id'] as int? ?? 0;

        if (cityName.isNotEmpty && cityId > 0) {
          final key = '$cityName-$cityId';
          allCities[key] = {
            'name': cityName,
            'id': cityId,
            'main_region_id': mainRegionId,
          };
        }
      }
    } else {
      print('   ❌ Ошибка: ${response.statusCode}');
      print('   📝 Response: ${response.body}');
    }
  } catch (e) {
    print('   ❌ Исключение: $e');
  }
}

/// Альтернативный поиск по запросу (если ДНР не найдена в списке регионов)
Future<void> _searchCitiesByQuery(String baseUrl, String query) async {
  print('Ищем города по запросу "$query"...\n');

  try {
    var searchUri = Uri.parse('$baseUrl/addresses/search');
    searchUri = searchUri.replace(queryParameters: {
      'q': query,
      'types[]': 'city',
    });

    final response = await http.get(
      searchUri,
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];

      print('✅ Найдено результатов: ${results.length}\n');

      final cities = <String, Map<String, dynamic>>{};
      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionId = mainRegion['id'] as int? ?? 0;
        final mainRegionName = mainRegion['name'] as String? ?? '';

        if (cityName.isNotEmpty && cityId > 0) {
          final key = '$cityName-$cityId';
          cities[key] = {
            'name': cityName,
            'id': cityId,
            'main_region_id': mainRegionId,
            'main_region_name': mainRegionName,
          };
        }
      }

      if (cities.isNotEmpty) {
        final sortedCities = cities.values.toList();
        sortedCities.sort((a, b) {
          final nameA = (a['name'] as String?) ?? '';
          final nameB = (b['name'] as String?) ?? '';
          return nameA.compareTo(nameB);
        });

        print('───────────────────────────────────────\n');
        for (int i = 0; i < sortedCities.length; i++) {
          final city = sortedCities[i];
          final name = city['name'] as String? ?? '';
          final mainRegionName = city['main_region_name'] as String? ?? '';
          print('${(i + 1).toString().padLeft(3)}. $name (Region: $mainRegionName)');
        }
        print('\n───────────────────────────────────────');
        print('Всего: ${cities.length} городов\n');
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
      print('📝 Response: ${response.body}');
    }
  } catch (e) {
    print('❌ ОШИБКА: $e');
  }
}
