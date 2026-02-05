import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const String apiUrl = 'https://dev-api.lidle.io/v1/adverts';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImF1ZCI6Imh0dHBzOi8vZGV2LWFwaS5saWRsZS5pby8iLCJpYXQiOjE3MzgyMjczODEsImV4cCI6MTczODMxMzc4MSwidXNlcl9pZCI6MSwibmFtZSI6InRlc3R1c2VyIiwiZW1haWwiOiJ3b3JreXVyeTAyQGdtYWlsLmNvbSIsInBob25lIjoiMzgwOTEyMzQ1Njc4IiwiYXZhdGFyIjpudWxsLCJyb2xlIjoiY3VzdG9tZXIifQ.R2o-nUGZPZnM8Iw_Bnj6A37qjvnJCDGVWJU4XbnVy7k';

  // Правильная структура payload для категории 2
  final Map<String, dynamic> payload = {
    "region_id": 1, // main_region.id
    "address": {
      "region_id": 13, // region.id (sub-region), NOT main_region
      "city_id": 70, // Мариуполь
      "street_id": 9199, // ул. Артёма
      "building": "123",
    },
    "category_id": 2,
    "title": "Новое объявление",
    "description": "Описание объявления",
    "phone_id": 21, // Правильный контакт для пользователя
    "email_id": 18, // Правильный контакт для пользователя
    "attributes": {
      "value_selected": [
        42, // Attribute 6 - 3 комнаты
        174, // Attribute 19 - Частное лицо
      ],
      "values": {
        // Атрибут 1040 - Этаж (диапазон)
        "1040": {"value": 4, "max_value": 5},
        // Атрибут 1127 - Общая площадь (диапазон)
        "1127": {"value": 50, "max_value": 100},
      },
    },
    // Атрибут 1048 - это логический тип (boolean), не требует value_id
    "attribute_1048": true, // Вам предложат цену
  };

  print("=== Отправляем объявление ===");
  print("Payload: ${jsonEncode(payload)}");
  print("");

  try {
    final request = await HttpClient().postUrl(Uri.parse(apiUrl));
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');

    request.write(utf8.encode(jsonEncode(payload)));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    print("Status: ${response.statusCode}");
    print("Response: $body");

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("\n✅ Объявление успешно создано!");
    } else {
      print("\n❌ Ошибка создания объявления");
    }
  } catch (e) {
    print("Ошибка запроса: $e");
  }
}
