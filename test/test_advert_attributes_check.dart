/// Тест для проверки структуры объявления и наличия attributes
/// Задача: выяснить, что реально возвращает API и где находятся характеристики
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String advertId = '66'; // ID объявления из логов

  // Токен из логов - скопируйте свой актуальный токен
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MTQwODQ4MSwiZXhwIjoxNzcxNDEyMDgxLCJuYmYiOjE3NzE0MDg0ODEsImp0aSI6IkF6V2p4MmFXMkFuNEU0RE4iLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.QeuSPxhvtF-xr3dUjbC3JIgdPGdiAdXKr9wDkFR-qTE';

  print('═══════════════════════════════════════════════════');
  print('🔍 Проверка структуры объявления $advertId');
  print('═══════════════════════════════════════════════════\n');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9',
    'Content-Type': 'application/json',
  };

  // Вариант 1: Базовый запрос (как в приложении сейчас)
  print('📍 ЗАПРОС 1: Базовый /adverts/$advertId');
  print('URL: $baseUrl/adverts/$advertId\n');

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/adverts/$advertId'),
      headers: headers,
    );

    print('Status: ${response.statusCode}\n');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      print('✅ ПОЛНЫЙ ОТВЕТ (приведен ниже):\n');
      print(jsonEncode(data));

      print('\n═════════════════════════════════════════════════');
      print('📋 АНАЛИЗ ОТВЕТА:');
      print('═════════════════════════════════════════════════\n');

      if (data['data'] != null) {
        final advert = data['data'] as Map<String, dynamic>;

        // Проверяем наличие attributes
        if (advert.containsKey('attributes')) {
          print('✅ НАЙДЕНЫ attributes!');
          print('Структура attributes:');
          print(jsonEncode(advert['attributes']));
        } else {
          print('❌ attributes НЕ НАЙДЕНЫ в response');
          print('Доступные поля: ${advert.keys.toList()}');
        }

        // Проверяем другие поля
        print('\n📊 Основные поля объявления:');
        print('  • id: ${advert['id']}');
        print('  • name: ${advert['name']}');
        print('  • address: ${advert['address']}');
        print('  • price: ${advert['price']}');
        print('  • images count: ${(advert['images'] as List?)?.length ?? 0}');
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Исключение: $e');
  }

  print('\n═════════════════════════════════════════════════\n');

  // Вариант 2: Запрос с параметром ?with=attributes
  print('📍 ЗАПРОС 2: С параметром ?with=attributes');
  print('URL: $baseUrl/adverts/$advertId?with=attributes\n');

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/adverts/$advertId?with=attributes'),
      headers: headers,
    );

    print('Status: ${response.statusCode}\n');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['data'] != null) {
        final advert = data['data'] as Map<String, dynamic>;

        if (advert.containsKey('attributes')) {
          print('✅ НАЙДЕНЫ attributes с параметром ?with=attributes!');
          print('Структура attributes:');
          print(jsonEncode(advert['attributes']));
        } else {
          print('❌ attributes отсутствуют даже с ?with=attributes');
        }
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Исключение: $e');
  }

  print('\n═════════════════════════════════════════════════\n');

  // Вариант 3: Запрос с параметром ?expand=attributes
  print('📍 ЗАПРОС 3: С параметром ?expand=attributes');
  print('URL: $baseUrl/adverts/$advertId?expand=attributes\n');

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/adverts/$advertId?expand=attributes'),
      headers: headers,
    );

    print('Status: ${response.statusCode}\n');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['data'] != null) {
        final advert = data['data'] as Map<String, dynamic>;

        if (advert.containsKey('attributes')) {
          print('✅ НАЙДЕНЫ attributes с параметром ?expand=attributes!');
          print('Структура attributes:');
          print(jsonEncode(advert['attributes']));
        } else {
          print('❌ attributes отсутствуют даже с ?expand=attributes');
        }
      }
    } else {
      print('❌ Ошибка: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Исключение: $e');
  }

  print('\n═════════════════════════════════════════════════');
  print('✅ Тест завершён');
  print('═════════════════════════════════════════════════');
}
