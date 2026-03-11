import 'package:dio/dio.dart';

/// Тест для диагностики API фильтров
/// Проверяет какие может вернуть API с разными параметрами фильтрации

void main() async {
  print('\n🔍 ═══════════════════════════════════════════════════════');
  print('🔍 API FILTER DIAGNOSIS TEST');
  print('🔍 ═══════════════════════════════════════════════════════\n');

  const String baseUrl = 'https://api.lidle.locahost';
  // const String baseUrl = 'https://lidle-api.co.uk';
  final dio = Dio();

  try {
    // ========== TEST 1: ALL APARTMENTS (no filters) ==========
    print('📝 TEST 1: Все объявления (category_id=2, без фильтров)');
    try {
      final response1 = await dio.get(
        '$baseUrl/adverts',
        queryParameters: {
          'category_id': 2,
          'page': 1,
          'limit': 5,
        },
      );
      final count1 = response1.data['data']?.length ?? 0;
      print('   ✅ РЕЗУЛЬТАТ: $count1 объявлений\n');
    } catch (e) {
      print('   ❌ ОШИБКА: $e\n');
    }

    // ========== TEST 2: FILTER BY ROOM COUNT ONLY (value_selected[6][0]=40) ==========
    print(
        '📝 TEST 2: Apenas filtro de quartos (1 comodo, ID=40, sem cidade)');
    try {
      final response2 = await dio.get(
        '$baseUrl/adverts',
        queryParameters: {
          'category_id': 2,
          'page': 1,
          'limit': 5,
          'filters[value_selected][6][0]': '40',
        },
      );
      final count2 = response2.data['data']?.length ?? 0;
      print('   ✅ РЕЗУЛЬТАТ: $count2 объявлений');
      if (count2 > 0) {
        print('   🎯 ПЕРВОЕ ОБЪЯВЛЕНИЕ:');
        final first = response2.data['data'][0];
        print('      ID: ${first['id']}');
        print('      Title: ${first['title']}');
      }
      print('');
    } catch (e) {
      print('   ❌ ОШИБКА: $e\n');
    }

    // ========== TEST 3: FILTER BY 6+ ROOMS ==========
    print('📝 TEST 3: Фильтр по комнатам 6+ (ID=45, без города)');
    try {
      final response3 = await dio.get(
        '$baseUrl/adverts',
        queryParameters: {
          'category_id': 2,
          'page': 1,
          'limit': 5,
          'filters[value_selected][6][0]': '45',
        },
      );
      final count3 = response3.data['data']?.length ?? 0;
      print('   ✅ РЕЗУЛЬТАТ: $count3 объявлений\n');
    } catch (e) {
      print('   ❌ ОШИБКА: $e\n');
    }

    // ========== TEST 4: List all available room options (GET attributes) ==========
    print('📝 TEST 4: Получить все доступные опции комнат (атрибут ID=6)');
    try {
      final responseAttrs = await dio.get(
        '$baseUrl/categories/2/attributes',
        queryParameters: {
          'include': 'values',
        },
      );

      // Find attribute ID=6
      final attrs = responseAttrs.data['data'] as List? ?? [];
      final roomAttr = attrs.firstWhere(
        (attr) => attr['id'] == 6,
        orElse: () => null,
      );

      if (roomAttr != null) {
        print('   ✅ Атрибут найден: ${roomAttr['title']}');
        final roomValues = roomAttr['values'] as List? ?? [];
        print('   📍 Доступные опции:');
        for (var val in roomValues) {
          print('      ID=${val['id']}: ${val['value']}');
        }
      } else {
        print('   ❌ Атрибут ID=6 не найден');
      }
      print('');
    } catch (e) {
      print('   ❌ ОШИБКА: $e\n');
    }

    // ========== TEST 5: Check which apartments HAVE room attribute data ==========
    print('📝 TEST 5: Проверить какие компания имеют данные о комнатах');
    try {
      final response5 = await dio.get(
        '$baseUrl/adverts',
        queryParameters: {
          'category_id': 2,
          'page': 1,
          'limit': 10,
          'include': 'attributes',
        },
      );
      final adverts = response5.data['data'] as List? ?? [];
      print('   📊 Проверили ${adverts.length} объявлений:');
      int withRoomData = 0;
      for (var advert in adverts) {
        final attrs = advert['attributes'] as Map? ?? {};
        if (attrs.containsKey('6') || attrs['6'] != null) {
          withRoomData++;
          final roomValue = attrs['6'];
          print('      ✅ ID=${advert['id']}: Комнаты = $roomValue');
        }
      }
      print('   📈 Объявлений с данными о комнатах: $withRoomData/${adverts.length}\n');
    } catch (e) {
      print('   ❌ ОШИБКА: $e\n');
    }

    // ========== TEST 6: Direct combination - city + room filter ==========
    print('📝 TEST 6: Комбинированный фильтр - город пгт. Александровка + 1 комната');
    try {
      // Note: city_id NOT sent to API (client-side only)
      final response6 = await dio.get(
        '$baseUrl/adverts',
        queryParameters: {
          'category_id': 2,
          'page': 1,
          'limit': 20,
          'filters[value_selected][6][0]': '40',
          // 'filters[city_id]': '408', // NOT SENT - would cause conflict
        },
      );
      final count6 = response6.data['data']?.length ?? 0;
      print('   ✅ РЕЗУЛЬТАТ (без city_id): $count6 объявлений');
      if (count6 > 0) {
        print('   🔍 Проверяем города в результатах:');
        final adverts = response6.data['data'] as List? ?? [];
        final uniqueCities = <String>{};
        for (var adv in adverts) {
          final city = adv['city'];
          if (city != null) {
            uniqueCities.add(city);
          }
        }
        print('   📍 Города: ${uniqueCities.join(", ")}');
      }
      print('');
    } catch (e) {
      print('   ❌ ОШИБКА: $e\n');
    }

    print('🔍 ═══════════════════════════════════════════════════════');
    print('🔍 DIAGNOSIS COMPLETE');
    print('🔍 ═══════════════════════════════════════════════════════\n');
  } catch (e) {
    print('❌ FATAL ERROR: $e');
  }
}
