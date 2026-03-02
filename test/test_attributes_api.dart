import 'dart:convert';
import 'dart:io';

void main() async {
  final baseUrl = 'https://dev-api.lidle.io/v1';
  final token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwaS5saWR6YS50ZXN0L3YxL2F1dGgvbG9naW4iLCJpYXQiOjE3NTExMDM4NzIsImV4cCI6MTc1MTEwNzQ3MiwibmJmIjoxNzUxMTAzODcyLCJqdGkiOiJHd2tidlhXNmV5bVZ4Mk5yIiwic3ViIjoiMSIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.iJ0fH_lXmsSYWDX-XN713q7x6pLHfg0qoMb44dCvg60';

  print('=== Тестирование получения атрибутов объявлений ===\n');

  // Тест 1: БЕЗ параметра
  print('📋 TEST 1: Без парамтра атрибутов');
  await testGetAdverts(baseUrl, token, null);

  print('\n---\n');

  // Тест 2: С with=attributes
  print('📋 TEST 2: С параметром with=attributes');
  await testGetAdverts(baseUrl, token, 'with=attributes');

  print('\n---\n');

  // Тест 3: С include=attributes
  print('📋 TEST 3: С параметром include=attributes');
  await testGetAdverts(baseUrl, token, 'include=attributes');

  print('\n---\n');

  // Тест 4: Запрос одного объявления с with=attributes
  print('📋 TEST 4: Одно объявление с with=attributes');
  await testGetSingleAdvert(baseUrl, token, 1);
}

Future<void> testGetAdverts(
  String baseUrl,
  String token,
  String? extraParam,
) async {
  var url = '$baseUrl/adverts?category_id=2&page=1&limit=20';
  if (extraParam != null) {
    url += '&$extraParam';
  }

  print('URL: $url\n');

  final uri = Uri.parse(url);
  final client = HttpClient();

  try {
    final request = await client.getUrl(uri);
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('Accept', 'application/json');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data.containsKey('data')) {
        final adverts = data['data'] as List;
        print('✅ Получено ${adverts.length} объявлений');

        if (adverts.isNotEmpty) {
          final firstAdvert = adverts[0] as Map<String, dynamic>;
          print(
            '   ID fields в первом объявлении: ${firstAdvert.keys.toList()}',
          );
          print(
            '   Содержит attributes? ${firstAdvert.containsKey('attributes')}',
          );

          if (firstAdvert.containsKey('attributes')) {
            final attrs = firstAdvert['attributes'];
            if (attrs is Map) {
              print('   attributes.keys: ${(attrs as Map).keys.toList()}');
            } else if (attrs is List) {
              print(
                '   attributes - это List с ${(attrs as List).length} элементами',
              );
            }
          }

          // Выводим все ключи
          print('\n   Все ключи первого объявления:');
          firstAdvert.forEach((key, value) {
            final typeStr = value.runtimeType.toString();
            if (value is Map) {
              print(
                '     • $key: Map with keys ${(value as Map).keys.toList()}',
              );
            } else if (value is List) {
              print('     • $key: List with ${(value as List).length} items');
            } else {
              print(
                '     • $key: $typeStr = ${value.toString().substring(0, 50)}...',
              );
            }
          });
        }
      } else {
        print('❌ Нет поля data в ответе');
        print('   Ключи в ответе: ${data.keys.toList()}');
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
      print('Body: ${body.substring(0, 200)}...');
    }
  } catch (e) {
    print('❌ Exception: $e');
  } finally {
    client.close();
  }
}

Future<void> testGetSingleAdvert(
  String baseUrl,
  String token,
  int advertId,
) async {
  var url = '$baseUrl/adverts/$advertId?with=attributes';

  print('URL: $url\n');

  final uri = Uri.parse(url);
  final client = HttpClient();

  try {
    final request = await client.getUrl(uri);
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('Accept', 'application/json');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data.containsKey('data')) {
        final advert = data['data'];
        if (advert is List && advert.isNotEmpty) {
          final advertData = advert[0] as Map<String, dynamic>;
          print('✅ Получено объявление');
          print('   ID fields: ${advertData.keys.toList()}');
          print(
            '   Содержит attributes? ${advertData.containsKey('attributes')}',
          );

          if (advertData.containsKey('attributes')) {
            final attrs = advertData['attributes'];
            if (attrs is Map) {
              print('   attributes.keys: ${(attrs as Map).keys.toList()}');
            } else if (attrs is List) {
              print(
                '   attributes - это List с ${(attrs as List).length} элементами',
              );
            }
          }
        }
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  } finally {
    client.close();
  }
}
