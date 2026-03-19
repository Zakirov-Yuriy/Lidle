import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  String? token;

  print('');
  print('═══════════════════════════════════════════════════════════');
  print('🔍 ПОЛНАЯ ДИАГНОСТИКА: Все города ДНР в API');
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

    // Найти ДНР
    Map<String, dynamic>? dnrRegion;
    for (final region in regionsList) {
      final name = region['name'] as String? ?? '';
      if (name.toLowerCase().contains('донец')) {
        dnrRegion = region as Map<String, dynamic>;
        break;
      }
    }

    if (dnrRegion == null) {
      print('❌ ДНР не найдена!');
      return;
    }

    final dnrId = dnrRegion['id'] as int? ?? 0;
    final dnrName = dnrRegion['name'] as String? ?? 'Неизвестно';
    print('✅ Найдена ДНР: "$dnrName" (ID: $dnrId)\n');

    // Шаг 2: Загрузить города несколькими способами
    print('🏙️  Шаг 2: Загружаем города (множественные методы поиска)...\n');

    final allCities = <String, Map<String, dynamic>>{};

    // Метод 1: Полный поиск - все возможные варианты
    print('📌 Метод 1: Поиск с минимальной строкой "   "...');
    await searchAndAdd(baseUrl, '   ', allCities, token);

    // Метод 2: По названию региона
    print('📌 Метод 2: Поиск по названию области "$dnrName"...');
    await searchAndAdd(baseUrl, dnrName, allCities, token);

    // Метод 3: Различные префиксы
    print('📌 Метод 3: Поиск по различным префиксам...');
    final prefixes = [
      'г.',
      'г ',
      'город',
      'пгт',
      'П',
      'п.',
      'П.',
      'с.',
      'с ',
      'село',
      'Донец',
      'Донск',
      'ДНР',
    ];
    for (final prefix in prefixes) {
      await searchAndAdd(baseUrl, prefix, allCities, token);
    }

    // Метод 4: Буквы одиночные
    print('📌 Метод 4: Поиск по отдельным буквам...');
    for (int charCode = 1040; charCode <= 1071; charCode++) {
      // Кириллица А-Я
      final letter = String.fromCharCode(charCode);
      await searchAndAdd(baseUrl, letter, allCities, token, verbose: false);
    }

    // Шаг 3: Вывести результаты
    print('\n═══════════════════════════════════════════════════════════');
    print('📊 РЕЗУЛЬТАТЫ: Все найденные города ДНР (${allCities.length} шт.)');
    print('═══════════════════════════════════════════════════════════\n');

    if (allCities.isEmpty) {
      print('⚠️  Города не найдены!\n');
      return;
    }

    final sortedCities = allCities.values.toList();
    sortedCities.sort((a, b) {
      final nameA = (a['name'] as String?) ?? '';
      final nameB = (b['name'] as String?) ?? '';
      return nameA.compareTo(nameB);
    });

    // Вывод списка
    for (int i = 0; i < sortedCities.length; i++) {
      final city = sortedCities[i];
      final name = city['name'] as String? ?? '';
      final id = city['id'] as int? ?? 0;
      print('${(i + 1).toString().padLeft(3)}. $name (ID: $id)');
    }

    print('\n═══════════════════════════════════════════════════════════');
    print('✅ ИТОГО: ${allCities.length} городов найдено');
    print('═══════════════════════════════════════════════════════════\n');

    // Код для использования
    print('📋 Dart код для проекта:\n');
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

/// Поиск и добавление городов
Future<void> searchAndAdd(
  String baseUrl,
  String query,
  Map<String, Map<String, dynamic>> cities,
  String? token, {
  bool verbose = true,
}) async {
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
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];

      if (verbose) {
        print('      ✅ Найдено: ${results.length}');
      }

      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionName = mainRegion['name'] as String? ?? '';

        // Фильтруем только ДНР
        if (mainRegionName.toLowerCase().contains('донец')) {
          if (cityName.isNotEmpty && cityId > 0) {
            final key = '$cityName-$cityId';
            if (!cities.containsKey(key)) {
              cities[key] = {
                'name': cityName,
                'id': cityId,
              };
            }
          }
        }
      }
    }
  } catch (e) {
    // Игнорируем ошибки поиска
  }
}
