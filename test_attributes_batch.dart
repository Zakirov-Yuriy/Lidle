import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

const baseUrl = 'https://lidle-backend.testinline.com';

Future<void> main() async {
  print('\n📊 Testing batch attributes loading...\n');

  // 1️⃣ Получаем список объявлений БЕЗ атрибутов
  print('1️⃣  Fetching list of advertisements (WITHOUT attributes)...');
  final listResponse = await http.get(
    Uri.parse('$baseUrl/api/adverts?category_id=4&limit=10'),
  );

  final listData = json.decode(listResponse.body);
  final adverts = (listData['data'] as List).cast<Map<String, dynamic>>();

  print('   ✅ Got ${adverts.length} adverts');
  final advertIds = adverts.map((a) => a['id'] as int).toList();
  print('   IDs: $advertIds');

  // 2️⃣ Проверяем: есть ли атрибуты в list response?
  print('\n2️⃣  Checking if attributes are in list response...');
  for (final advert in adverts) {
    if (advert['attributes'] != null) {
      print(
        '   ✅ Advert ${advert['id']} HAS attributes: ${advert['attributes']}',
      );
    } else {
      print('   ❌ Advert ${advert['id']} NO attributes');
    }
  }

  // 3️⃣ Загружаем атрибуты для каждого объявления по одному
  print('\n3️⃣  Loading attributes for each advert individually...');
  final advertsWithAttributes = <Map<String, dynamic>>[];

  // Ограничиваем для тестирования (максимум 3 объявления)
  final testIds = advertIds.take(3).toList();

  for (final id in testIds) {
    final response = await http.get(
      Uri.parse('$baseUrl/api/adverts/$id?with=attributes'),
    );

    final data = json.decode(response.body);
    final advert = (data['data'] as List).isNotEmpty
        ? (data['data'] as List)[0]
        : data['data'];

    if (advert['attributes'] != null) {
      advertsWithAttributes.add(advert);
      print(
        '   ✅ Advert $id: ${advert['attributes'].keys.length} attribute groups',
      );
    } else {
      print('   ❌ Advert $id: NO attributes');
    }
  }

  // 4️⃣ Выводим структуру атрибутов
  print('\n4️⃣  Attributes structure for first advert:');
  if (advertsWithAttributes.isNotEmpty) {
    final attrs = advertsWithAttributes[0]['attributes'];
    print('   Type: ${attrs.runtimeType}');
    if (attrs is Map) {
      attrs.forEach((key, value) {
        print('   [$key]: ${value.runtimeType}');
        if (value is Map) {
          print('       keys: ${(value as Map).keys.toList()}');
        }
      });
    }
  }

  // 5️⃣ Параллельная загрузка (батч из 2)
  print('\n5️⃣  Testing batch loading (2 adverts in parallel)...');
  final batchSize = 2;
  final start = DateTime.now();

  for (int i = 0; i < testIds.length; i += batchSize) {
    final batch = testIds.sublist(
      i,
      (i + batchSize > testIds.length) ? testIds.length : i + batchSize,
    );

    print('   Batch $i-${i + batchSize}: $batch');

    final futures = batch.map(
      (id) => http.get(Uri.parse('$baseUrl/api/adverts/$id?with=attributes')),
    );

    final responses = await Future.wait(futures);
    print('   ✅ Loaded ${responses.length} adverts in parallel');
  }

  final duration = DateTime.now().difference(start);
  print('   ⏱️  Total time: ${duration.inMilliseconds}ms');

  print('\n✅ Test completed!\n');
}
