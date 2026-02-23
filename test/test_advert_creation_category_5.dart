/// Автотест для создания объявления в категории "Продажа комнат" (category_id=5)
///
/// Этот тест проверяет полный цикл создания объявления:
/// 1. Авторизация и получение токена
/// 2. Получение фильтров/атрибутов для категории 5
/// 3. Получение контактов пользователя
/// 4. Формирование корректного запроса
/// 5. Создание объявления
/// 6. Загрузка изображения
///
/// Категория 5: "Продажа комнат"
/// Отличия от категории 2 (Продажа квартир):
/// - Комната вместо целой квартиры
/// - Площадь комнаты меньше
/// - Другие атрибуты (без количества комнат)

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';

  // Тестовые учетные данные
  const String testEmail = 'sonyworkweb@gmail.com';
  const String testPassword = '12345678';

  print('═══════════════════════════════════════════════════════════════');
  print('🧪 АВТОТЕСТ: Создание объявления в категории "Продажа комнат"');
  print('═══════════════════════════════════════════════════════════════\n');

  String? token;

  // ============================================================
  // ШАГ 1: Авторизация
  // ============================================================
  print('📝 ШАГ 1: Авторизация...');
  print('─────────────────────────────────────────────────────────────');

  try {
    final loginResponse = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': testEmail,
        'password': testPassword,
        'remember': true,
      }),
    );

    print('Status: ${loginResponse.statusCode}');

    if (loginResponse.statusCode == 200) {
      final loginData = jsonDecode(loginResponse.body);
      token = loginData['access_token'];
      print('✅ Авторизация успешна!');
      print('   Token preview: ${token?.substring(0, 30)}...');
    } else {
      final errorData = jsonDecode(loginResponse.body);
      print('❌ Ошибка авторизации: ${errorData['message']}');
      return;
    }
  } catch (e) {
    print('❌ Исключение при авторизации: $e');
    return;
  }

  print('');

  // ============================================================
  // ШАГ 2: Получение атрибутов для создания объявления (category_id=5)
  // ============================================================
  print('📝 ШАГ 2: Получение атрибутов для создания объявления...');
  print('─────────────────────────────────────────────────────────────');

  List<dynamic> attributes = [];

  try {
    // Используем /adverts/create для получения атрибутов создания
    final createParamsResponse =
        await http.Request('GET', Uri.parse('$baseUrl/adverts/create'))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'X-App-Client': 'mobile',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({'category_id': 5});

    final streamedResponse = await createParamsResponse.send();
    final createParamsBody = await http.Response.fromStream(streamedResponse);

    print('Status: ${createParamsBody.statusCode}');

    if (createParamsBody.statusCode == 200) {
      final data = jsonDecode(createParamsBody.body);

      // Выводим структуру ответа для отладки
      print('📦 Структура ответа:');
      print('   data type: ${data.runtimeType}');
      print('   data.data exists: ${data['data'] != null}');

      // data['data'] может быть List или Map
      final dataNode = data['data'];
      print('   data.data type: ${dataNode?.runtimeType}');

      // Атрибуты могут быть в разных местах в зависимости от структуры
      dynamic attrsRaw;
      if (dataNode is List && dataNode.isNotEmpty) {
        // Если data.data это List, берём первый элемент
        final firstItem = dataNode[0] as Map<String, dynamic>?;
        attrsRaw = firstItem?['attributes'];
        print('   data.data[0].attributes exists: ${attrsRaw != null}');
      } else if (dataNode is Map<String, dynamic>) {
        attrsRaw = dataNode['attributes'];
        print('   data.data.attributes exists: ${attrsRaw != null}');
      }

      print('   attributes type: ${attrsRaw?.runtimeType}');

      if (attrsRaw is List) {
        attributes = attrsRaw;
      } else if (attrsRaw is Map) {
        // Если attributes это Map с числовыми ключами-строками
        attributes = attrsRaw.values.toList();
        print('   Converted Map to List: ${attributes.length} items');
      }

      print('✅ Получено ${attributes.length} атрибутов для создания');
      print('');
      print('📊 Список атрибутов для категории "Продажа комнат":');
      print(
        '┌────────┬────────────────────────────────────┬─────────┬──────────┬──────────┐',
      );
      print(
        '│   ID   │ Title                              │ is_range│is_multiple│ required │',
      );
      print(
        '├────────┼────────────────────────────────────┼─────────┼──────────┼──────────┤',
      );

      for (final attr in attributes) {
        try {
          // attr может быть Map с разными типами ключей
          final attrMap = attr as Map;

          // ID может быть int или String - приводим к int
          final idRaw = attrMap['id'];
          final id = idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0;
          final title = ((attrMap['title'] ?? '(без названия)') as String)
              .padRight(34);
          final isRange = attrMap['is_range'] ?? false;
          final isMultiple = attrMap['is_multiple'] ?? false;
          final isRequired = attrMap['is_required'] ?? false;
          final style = attrMap['style']?.toString() ?? 'null';
          final isPopup = attrMap['is_popup'] ?? false;
          final isSpecialDesign = attrMap['is_special_design'] ?? false;
          final isTitleHidden = attrMap['is_title_hidden'] ?? false;
          final dataType = attrMap['data_type']?.toString() ?? 'null';
          final valuesRaw = attrMap['values'];
          final valuesCount = (valuesRaw is List) ? valuesRaw.length : 0;

          print(
            '│ ${id.toString().padLeft(6)} │ $title │ ${isRange.toString().padLeft(7)} │ ${isMultiple.toString().padLeft(8)} │ ${isRequired.toString().padLeft(8)} │',
          );
          // Дополнительная информация о стиле
          print(
            '│        │ style=$style, is_popup=$isPopup, is_special_design=$isSpecialDesign, is_title_hidden=$isTitleHidden, data_type=$dataType',
          );

          if (valuesCount > 0 && valuesRaw is List) {
            print('│        │ Values ($valuesCount):');
            for (final val in valuesRaw.take(5)) {
              final valMap = val as Map;
              print('│        │   - ID=${valMap['id']}: "${valMap['value']}"');
            }
            if (valuesCount > 5) {
              print('│        │   ... и ещё ${valuesCount - 5}');
            }
          }
        } catch (e) {
          print('│ ERROR  │ Ошибка парсинга атрибута: $e');
        }
      }
      print(
        '└────────┴────────────────────────────────────┴─────────┴──────────┴──────────┘',
      );
    } else {
      print('❌ Ошибка получения атрибутов');
      print('   Response: ${createParamsBody.body}');
    }
  } catch (e, stackTrace) {
    print('❌ Исключение при получении атрибутов: $e');
    print('   StackTrace: $stackTrace');
  }

  print('');

  // ============================================================
  // ШАГ 3: Получение контактов пользователя
  // ============================================================
  print('📝 ШАГ 3: Получение контактов пользователя...');
  print('─────────────────────────────────────────────────────────────');

  int? userPhoneId;
  int? userEmailId;

  try {
    // Получаем телефоны
    final phonesResponse = await http.get(
      Uri.parse('$baseUrl/me/settings/phones'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
      },
    );

    if (phonesResponse.statusCode == 200) {
      final phonesData = jsonDecode(phonesResponse.body);
      final phones = phonesData['data'] as List?;
      if (phones != null && phones.isNotEmpty) {
        userPhoneId = phones[0]['id'];
        print('✅ Телефон: ID=$userPhoneId, number=${phones[0]['phone']}');
      }
    }

    // Получаем email
    final emailsResponse = await http.get(
      Uri.parse('$baseUrl/me/settings/emails'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
      },
    );

    if (emailsResponse.statusCode == 200) {
      final emailsData = jsonDecode(emailsResponse.body);
      final emails = emailsData['data'] as List?;
      if (emails != null && emails.isNotEmpty) {
        userEmailId = emails[0]['id'];
        print('✅ Email: ID=$userEmailId, email=${emails[0]['email']}');
      }
    }
  } catch (e) {
    print('❌ Исключение при получении контактов: $e');
  }

  if (userPhoneId == null) {
    print('❌ ОШИБКА: Не удалось получить ID телефона пользователя');
    return;
  }

  print('');

  // ============================================================
  // ШАГ 4: Поиск адреса
  // ============================================================
  print('📝 ШАГ 4: Поиск адреса...');
  print('─────────────────────────────────────────────────────────────');

  int? mainRegionId;
  int? addressRegionId;
  int? cityId;
  int? streetId;

  try {
    // Ищем город Мариуполь
    final addressResponse =
        await http.Request('GET', Uri.parse('$baseUrl/addresses/search'))
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'X-App-Client': 'mobile',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'q': 'Мариуполь',
            'types': ['city'],
          });

    final streamedResponse = await addressResponse.send();
    final addressBody = await http.Response.fromStream(streamedResponse);

    if (addressBody.statusCode == 200) {
      final addressData = jsonDecode(addressBody.body);
      final results = addressData['data'] as List?;

      if (results != null && results.isNotEmpty) {
        final firstResult = results[0];
        mainRegionId = firstResult['main_region']?['id'];
        addressRegionId = firstResult['region']?['id'];
        cityId = firstResult['city']?['id'];

        print('✅ Найден город:');
        print('   main_region.id: $mainRegionId');
        print('   region.id: $addressRegionId');
        print('   city.id: $cityId');
      }
    }

    // Ищем улицу
    if (cityId != null) {
      final streetResponse =
          await http.Request('GET', Uri.parse('$baseUrl/addresses/search'))
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'X-App-Client': 'mobile',
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({
              'q': 'Артёма',
              'types': ['street'],
              'filters': {'city_id': cityId},
            });

      final streetStreamedResponse = await streetResponse.send();
      final streetBody = await http.Response.fromStream(streetStreamedResponse);

      if (streetBody.statusCode == 200) {
        final streetData = jsonDecode(streetBody.body);
        final streetResults = streetData['data'] as List?;

        if (streetResults != null && streetResults.isNotEmpty) {
          streetId = streetResults[0]['street']?['id'];
          print('✅ Найдена улица: street.id=$streetId');
        }
      }
    }
  } catch (e) {
    print('❌ Исключение при поиске адреса: $e');
  }

  print('');

  // ============================================================
  // ШАГ 5: Формирование запроса на создание объявления
  // ============================================================
  print('📝 ШАГ 5: Формирование запроса...');
  print('─────────────────────────────────────────────────────────────');

  // Находим нужные value_id для атрибутов категории 5
  int? sellerTypeValueId; // ID для "Частное лицо" (обязательный атрибут!)
  int? offerPriceAttrId; // ID атрибута "Вам предложат цену" (обязательный!)
  int? areaAttrId; // ID атрибута "Общая площадь" (обязательный!)
  int? floorAttrId; // ID атрибута "Этаж"
  int? bargainValueId; // ID для "Возможен торг"
  int? roomsValueId; // ID для "Количество комнат" (ОБЯЗАТЕЛЬНЫЙ атрибут!)

  for (final attr in attributes) {
    // ID может быть int или String - приводим к int
    final attrIdRaw = attr['id'];
    final attrId = attrIdRaw is int
        ? attrIdRaw
        : int.tryParse(attrIdRaw.toString()) ?? 0;
    final attrTitle = attr['title'] ?? '';

    // Частное лицо / Бизнес (ОБЯЗАТЕЛЬНЫЙ атрибут!)
    if (attrTitle == 'Частное лицо / Бизнес' ||
        attrTitle == 'Частное лицо / Бизнес*') {
      final values = attr['values'] as List?;
      if (values != null && values.isNotEmpty) {
        // Берём "Частное лицо" (первое значение)
        sellerTypeValueId = values[0]['id'];
        print(
          '✅ Найден ID для "Частное лицо": $sellerTypeValueId (атрибут $attrId)',
        );
      }
    }

    // Вам предложат цену (ОБЯЗАТЕЛЬНЫЙ атрибут!)
    if (attrTitle == 'Вам предложат цену' ||
        attrTitle == 'Вам предложат цену*') {
      offerPriceAttrId = attrId;
      print('✅ Найден атрибут "Вам предложат цену": ID=$offerPriceAttrId');
    }

    // Общая площадь (ОБЯЗАТЕЛЬНЫЙ атрибут!)
    if (attrTitle == 'Общая площадь' || attrTitle == 'Общая площадь*') {
      areaAttrId = attrId;
      print('✅ Найден атрибут "Общая площадь": ID=$areaAttrId');
    }

    // Этаж
    if (attrTitle == 'Этаж' || attrTitle == 'Этаж*') {
      floorAttrId = attrId;
      print('✅ Найден атрибут "Этаж": ID=$floorAttrId');
    }

    // Возможен торг
    if (attrTitle == 'Возможен торг') {
      final values = attr['values'] as List?;
      if (values != null && values.isNotEmpty) {
        bargainValueId = values[0]['id'];
        print('✅ Найден ID для "Возможен торг": $bargainValueId');
      }
    }

    // Количество комнат (ОБЯЗАТЕЛЬНЫЙ атрибут для категории 5!)
    if (attrTitle == 'Количество комнат' || attrTitle == 'Количество комнат*') {
      final values = attr['values'] as List?;
      if (values != null && values.isNotEmpty) {
        // Берём "1" (первое значение) - одна комната
        roomsValueId = values[0]['id'];
        print('✅ Найден ID для "1 комната": $roomsValueId (атрибут $attrId)');
      }
    }
  }

  // Формируем attributes для API
  final Map<String, dynamic> requestAttributes = {
    'value_selected': <int>[],
    'values': <String, dynamic>{},
  };

  // Добавляем "Частное лицо" (ОБЯЗАТЕЛЬНЫЙ атрибут!)
  if (sellerTypeValueId != null) {
    requestAttributes['value_selected'].add(sellerTypeValueId);
    print('   Добавлено в value_selected: $sellerTypeValueId (Частное лицо)');
  } else {
    print(
      '⚠️ ВНИМАНИЕ: Не найден обязательный атрибут "Частное лицо / Бизнес"!',
    );
  }

  // Добавляем "Возможен торг"
  if (bargainValueId != null) {
    requestAttributes['value_selected'].add(bargainValueId);
    print('   Добавлено в value_selected: $bargainValueId (Возможен торг)');
  }

  // Добавляем "Количество комнат" (ОБЯЗАТЕЛЬНЫЙ атрибут!)
  if (roomsValueId != null) {
    requestAttributes['value_selected'].add(roomsValueId);
    print('   Добавлено в value_selected: $roomsValueId (1 комната)');
  } else {
    print('⚠️ ВНИМАНИЕ: Не найден обязательный атрибут "Количество комнат"!');
    // Устанавливаем дефолтный ID для "1 комната"
    requestAttributes['value_selected'].add(436);
    print('   Используем дефолтный ID 436 для "1 комната"');
  }

  // Добавляем "Вам предложат цену" (ОБЯЗАТЕЛЬНЫЙ атрибут!)
  // Это булевый атрибут - передаём {value: 1} в values
  if (offerPriceAttrId != null) {
    requestAttributes['values'][offerPriceAttrId.toString()] = {'value': 1};
    print(
      '   Добавлено в values[$offerPriceAttrId]: {value: 1} (Вам предложат цену)',
    );
  } else {
    print('⚠️ ВНИМАНИЕ: Не найден обязательный атрибут "Вам предложат цену"!');
    // Устанавливаем дефолтный ID для категории 5
    requestAttributes['values']['1052'] = {'value': 1};
    print('   Используем дефолтный ID 1052 для "Вам предложат цену"');
  }

  // Добавляем "Общая площадь" (ОБЯЗАТЕЛЬНЫЙ атрибут!)
  if (areaAttrId != null) {
    requestAttributes['values'][areaAttrId.toString()] = {'value': 18.5};
    print('   Добавлено в values[$areaAttrId]: {value: 18.5} (Общая площадь)');
  } else {
    print('⚠️ ВНИМАНИЕ: Не найден обязательный атрибут "Общая площадь"!');
    // Устанавливаем дефолтный ID для категории 5
    requestAttributes['values']['1130'] = {'value': 18.5};
    print('   Используем дефолтный ID 1130 для "Общая площадь"');
  }

  // Добавляем "Этаж"
  if (floorAttrId != null) {
    requestAttributes['values'][floorAttrId.toString()] = {
      'value': 3,
      'max_value': 5,
    };
    print(
      '   Добавлено в values[$floorAttrId]: {value: 3, max_value: 5} (Этаж)',
    );
  }

  // Формируем полный запрос
  // Описание должно быть не длиннее 255 символов!
  const shortDescription =
      'Продаётся светлая комната 18 м² в трёхкомнатной квартире. '
      'Изолированная, с балконом, косметический ремонт. '
      'Кухня и санузел в совместном пользовании. Хорошие соседи, тихий район.';

  final createRequest = {
    'name': 'Тестовая комната 18 м² в продаже',
    'description': shortDescription, // ~180 символов
    'price': '850000', // Цена продажи комнаты
    'category_id': 5, // Продажа комнат
    'region_id': mainRegionId ?? 1, // main_region.id
    'address': {
      'region_id': addressRegionId,
      'city_id': cityId,
      'street_id': streetId,
      'building_number': '15',
    },
    'attributes': requestAttributes,
    'contacts': {
      'user_phone_id': userPhoneId,
      if (userEmailId != null) 'user_email_id': userEmailId,
    },
    'is_auto_renew': false,
  };

  print('');
  print('📦 Итоговый запрос:');
  print('─────────────────────────────────────────────────────────────');
  print(const JsonEncoder.withIndent('  ').convert(createRequest));
  print('');

  // ============================================================
  // ШАГ 6: Отправка запроса на создание объявления
  // ============================================================
  print('📝 ШАГ 6: Создание объявления...');
  print('─────────────────────────────────────────────────────────────');

  int? advertId;

  try {
    final createResponse = await http.post(
      Uri.parse('$baseUrl/adverts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(createRequest),
    );

    print('Status: ${createResponse.statusCode}');
    print('');

    final responseData = jsonDecode(createResponse.body);

    if (createResponse.statusCode == 201 || createResponse.statusCode == 200) {
      print('═══════════════════════════════════════════════════════════════');
      print('✅ ОБЪЯВЛЕНИЕ УСПЕШНО СОЗДАНО!');
      print('═══════════════════════════════════════════════════════════════');
      print('');
      print('Response:');
      print(const JsonEncoder.withIndent('  ').convert(responseData));

      // Извлекаем ID созданного объявления
      if (responseData['data'] != null) {
        if (responseData['data'] is List &&
            (responseData['data'] as List).isNotEmpty) {
          advertId = (responseData['data'] as List)[0]['id'];
        } else if (responseData['data'] is Map) {
          advertId = responseData['data']['id'];
        }
        if (advertId != null) {
          print('');
          print('🆔 ID созданного объявления: $advertId');
        }
      }
    } else {
      print('═══════════════════════════════════════════════════════════════');
      print('❌ ОШИБКА СОЗДАНИЯ ОБЪЯВЛЕНИЯ');
      print('═══════════════════════════════════════════════════════════════');
      print('');
      print('Message: ${responseData['message']}');

      if (responseData['errors'] != null) {
        print('');
        print('Ошибки валидации:');
        final errors = responseData['errors'] as Map;
        errors.forEach((key, value) {
          print('  ❌ $key: $value');
        });
      }

      print('');
      print('Full response:');
      print(const JsonEncoder.withIndent('  ').convert(responseData));
    }
  } catch (e) {
    print('❌ Исключение при создании объявления: $e');
  }

  // ============================================================
  // ШАГ 7: Загрузка изображения
  // ============================================================
  if (advertId != null) {
    print('');
    print('📝 ШАГ 7: Загрузка изображения...');
    print('─────────────────────────────────────────────────────────────');

    // Путь к тестовому изображению для категории 5 (Продажа комнат)
    // Используем изображение комнаты/квартиры
    final imagePath = 'assets/home_page/1700659569_t16.jpg';
    final imageFile = File(imagePath);

    if (await imageFile.exists()) {
      print('📷 Найден файл изображения: $imagePath');
      print('   Размер: ${await imageFile.length()} байт');

      try {
        // Создаём multipart запрос
        final uploadRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/adverts/$advertId/images'),
        );

        // Добавляем заголовки
        uploadRequest.headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'X-App-Client': 'mobile',
        });

        // Добавляем файл
        uploadRequest.files.add(
          await http.MultipartFile.fromPath('images[0]', imagePath),
        );

        print('📤 Отправка изображения на сервер...');

        final uploadStreamedResponse = await uploadRequest.send();
        final uploadResponse = await http.Response.fromStream(
          uploadStreamedResponse,
        );

        print('Status: ${uploadResponse.statusCode}');

        if (uploadResponse.statusCode == 200) {
          final uploadData = jsonDecode(uploadResponse.body);
          print(
            '═══════════════════════════════════════════════════════════════',
          );
          print('✅ ИЗОБРАЖЕНИЕ УСПЕШНО ЗАГРУЖЕНО!');
          print(
            '═══════════════════════════════════════════════════════════════',
          );
          print('');
          print('Response:');
          print(const JsonEncoder.withIndent('  ').convert(uploadData));
        } else {
          final uploadData = jsonDecode(uploadResponse.body);
          print('❌ Ошибка загрузки изображения:');
          print('   Message: ${uploadData['message']}');
          if (uploadData['errors'] != null) {
            print('   Errors: ${uploadData['errors']}');
          }
        }
      } catch (e) {
        print('❌ Исключение при загрузке изображения: $e');
      }
    } else {
      print('⚠️ Файл изображения не найден: $imagePath');
      print('   Пропускаем загрузку изображения.');
    }
  }

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('🏁 ТЕСТ ЗАВЕРШЁН');
  print('═══════════════════════════════════════════════════════════════');
}
