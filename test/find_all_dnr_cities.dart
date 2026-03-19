import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  String? token;

  print('');
  print('═══════════════════════════════════════════════════════════');
  print('🔍 ДИАГНОСТИКА: Поиск всех городов ДНР');
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
      print('   - $name');
      if (name.toLowerCase().contains('донец')) {
        dnrRegion = region as Map<String, dynamic>;
      }
    }

    if (dnrRegion == null) {
      print('\n❌ ДНР не найдена!');
      return;
    }

    final dnrId = dnrRegion['id'] as int? ?? 0;
    print('\n✅ Найдена: ДНР (ID: $dnrId)\n');

    // Загрузить города
    print('🏙️  Загружаем города...\n');

    final allCities = <String, Map<String, dynamic>>{};

    // Поиск 1: По названию региона
    print('📌 Поиск 1: По названию области...');
    await searchAndAdd(baseUrl, 'Донецкая Народная', allCities, token);

    // Поиск 2: По короткому названию
    print('📌 Поиск 2: По "Донец"...');
    await searchAndAdd(baseUrl, 'Донец', allCities, token);

    // Поиск 3: По типам
    print('📌 Поиск 3: По "город"...');
    await searchAndAdd(baseUrl, 'город', allCities, token);

    // Поиск 4: По "г."
    print('📌 Поиск 4: По "г."...');
    await searchAndAdd(baseUrl, 'г.', allCities, token);

    // Поиск 5: По "село"
    print('📌 Поиск 5: По "село"...');
    await searchAndAdd(baseUrl, 'село', allCities, token);

    // Поиск 6: По "пгт"
    print('📌 Поиск 6: По "пгт"...');
    await searchAndAdd(baseUrl, 'пгт', allCities, token);

    // Поиск 7: По первой букве
    print('📌 Поиск 7: По букве "Д"...');
    await searchAndAdd(baseUrl, 'Д', allCities, token);

    print('\n═══════════════════════════════════════════════════════════');
    print('📊 РЕЗУЛЬТАТЫ: ${allCities.length} городов найдено');
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
    print('✅ ВСЕГО: ${allCities.length} городов');
    print('═══════════════════════════════════════════════════════════\n');

    // Код для использования в проекте
    print('📋 Для использования в коде (Dart):\n');
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
Future<void> searchAndAdd(
  String baseUrl,
  String query,
  Map<String, Map<String, dynamic>> cities,
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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['data'] as List<dynamic>? ?? [];
      
      int addedCount = 0;

      for (final result in results) {
        final city = result['city'] as Map<String, dynamic>? ?? {};
        final mainRegion = result['main_region'] as Map<String, dynamic>? ?? {};

        final cityName = city['name'] as String? ?? '';
        final cityId = city['id'] as int? ?? 0;
        final mainRegionName = mainRegion['name'] as String? ?? '';

        // Только ДНР
        if (mainRegionName.toLowerCase().contains('донец')) {
          if (cityName.isNotEmpty && cityId > 0) {
            final key = '$cityName-$cityId';
            if (!cities.containsKey(key)) {
              cities[key] = {
                'name': cityName,
                'id': cityId,
              };
              addedCount++;
            }
          }
        }
      }
      
      print('   ✅ Найдено: ${results.length}, добавлено нових: $addedCount, всего: ${cities.length}');
    } else {
      print('   ❌ Ошибка: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Ошибка: $e');
  }
}
