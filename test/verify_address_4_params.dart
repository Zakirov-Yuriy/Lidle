import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const token =
      '11459|d4TjYynIMSkI0S3KxvILaP0VPH1LlacB7fVBYEebc7ea81c3'; // Из логов
  const advertId = '130';

  print('═══════════════════════════════════════════════════════');
  print('🔍 ПРОВЕРКА: Какие 4 параметра отправляются в API');
  print('═══════════════════════════════════════════════════════\n');

  // Новый адрес для редактирования
  const newRegion = 'Донецкая Народная респ.';
  const newCity = 'г. Донецк';
  const newStreet = 'ул. Донецкая';
  const newBuildingNumber = 'д. 70';

  print('📋 Новый адрес (4 параметра):');
  print('   1️⃣  Область: $newRegion');
  print('   2️⃣  Город: $newCity');
  print('   3️⃣  Улица: $newStreet');
  print('   4️⃣  Номер дома: $newBuildingNumber\n');

  print('═══════════════════════════════════════════════════════');
  print('📤 СТРУКТУРА ЗАПРОСА UPDATE (что отправляется)');
  print('═══════════════════════════════════════════════════════\n');

  // Формируем тело запроса как в коде
  Map<String, dynamic> requestBody = {
    'title': 'Тестовое обновление',
    'category': 1, // apartment
    'address': {
      'region': newRegion,
      'city': newCity,
      'street': newStreet,
      'building_number': newBuildingNumber,
    },
  };

  print('🔹 address object:');
  print(jsonEncode(requestBody['address']));
  print('');

  print('📊 Параметры по отдельности:');
  print('   region: ${requestBody['address']['region']}');
  print('   city: ${requestBody['address']['city']}');
  print('   street: ${requestBody['address']['street']}');
  print('   building_number: ${requestBody['address']['building_number']}');
  print('');

  print('═══════════════════════════════════════════════════════');
  print('🧪 ПОПЫТКА ОБНОВЛЕНИЯ (сухой запрос)');
  print('═══════════════════════════════════════════════════════\n');

  try {
    final response = await http.put(
      Uri.parse('https://dev-api.lidle.io/v1/adverts/$advertId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    print('✅ Статус ответа: ${response.statusCode}');
    print('');

    print('📥 Ответ API:');
    print(response.body);
    print('');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      print('✅ УСПЕШНО! Проверяем возвращенные данные адреса:');
        print('');

      if (data['data'] != null && data['data']['address'] != null) {
        final addressData = data['data']['address'];

        print('📦 Адрес в ответе API:');
        if (addressData is String) {
          print('   Type: String (объединенный)');
          print('   Value: "$addressData"');
        } else if (addressData is Map) {
          print('   Type: Map (раздельные компоненты)');
          print('   region: ${addressData['region']}');
          print('   city: ${addressData['city']}');
          print('   street: ${addressData['street']}');
          print('   building_number: ${addressData['building_number']}');
        }
      }
    } else if (response.statusCode == 422) {
      print('⚠️  Validation Error (422):');
      final errors = jsonDecode(response.body);
      print(jsonEncode(errors));
    } else {
      print('❌ Ошибка: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }

  print('\n═══════════════════════════════════════════════════════');
  print('📝 ВЫВОД:');
  print('═══════════════════════════════════════════════════════');
  print('''
✅ Когда мы редактируем, нужно отправить 4 параметра:
   1. region - область
   2. city - город 
   3. street - улица
   4. building_number - номер дома

⚠️  API при возврате может:
   - Возвращать address как объединенную строку
   - Или возвращать раздельные компоненты в пакете

💡 При редактировании ВАЖНО:
   - Убедиться что region, city, street, building_number
     заполнены все 4
   - Не пусто ли building_number?
   - Правильно ли парсится при загрузке для edit?
''');
}
