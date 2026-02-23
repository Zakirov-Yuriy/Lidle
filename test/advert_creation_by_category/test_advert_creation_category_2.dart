/// Автотест для создания объявления в категории "Продажа квартир" (category_id=2)
///
/// Этот тест проверяет полный цикл создания объявления:
/// 1. Авторизация и получение токена
/// 2. Получение фильтров/атрибутов для категории 2
/// 3. Получение контактов пользователя
/// 4. Формирование корректного запроса
/// 5. Создание объявления
///
/// Анализ атрибутов для категории "Продажа квартир" (category_id=2):
///
/// | ID    | Title                    | Type      | Values                    |
/// |-------|--------------------------|-----------|---------------------------|
/// | 6     | Количество комнат        | multiple  | 40=1, 41=2, 42=3, ...     |
/// | 14    | Комфорт                  | multiple  | Автономное отопление, ... |
/// | 17    | Инфраструктура           | multiple  | Исторические места, ...   |
/// | 18    | Ландшафт                 | multiple  | Река, Море, ...           |
/// | 19    | Частное лицо / Бизнес    | single    | Частное лицо, Бизнес      |
/// | 22    | Возможен торг            | boolean   | -                         |
/// | 1037  | Общая площадь            | range     | min/max                   |
/// | 1039  | Название ЖК              | text      | -                         |
/// | 1040  | Этаж                     | range     | min/max (value/max_value) |
/// | 1048  | Вам предложат цену       | boolean   | REQUIRED! (не в API)      |
/// | 1127  | Общая площадь            | simple    | value (не range!)         |
///
/// ВАЖНО:
/// - Атрибут 1048 ("Вам предложат цену") ОБЯЗАТЕЛЕН, но НЕ возвращается API!
/// - Атрибут 6 (Количество комнат) is_multiple=false - отправляем ОДНО значение
/// - Атрибут 1127 теперь простое поле, не range

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';

  // Тестовые учетные данные
  const String testEmail = 'sonyworkweb@gmail.com';
  const String testPassword = '12345678';

  print('═══════════════════════════════════════════════════════════════');
  print('🧪 АВТОТЕСТ: Создание объявления в категории "Продажа квартир"');
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
  // ШАГ 2: Получение фильтров для категории 2
  // ============================================================
  print('📝 ШАГ 2: Получение фильтров для категории 2...');
  print('─────────────────────────────────────────────────────────────');

  List<dynamic> filters = [];

  try {
    final filtersResponse = await http.get(
      Uri.parse('$baseUrl/meta/filters?category_id=2'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Content-Type': 'application/json',
      },
    );

    print('Status: ${filtersResponse.statusCode}');

    if (filtersResponse.statusCode == 200) {
      final data = jsonDecode(filtersResponse.body);
      filters = data['data']['filters'] ?? [];

      print('✅ Получено ${filters.length} фильтров');
      print('');
      print('📊 Список атрибутов:');

      for (final filter in filters) {
        final id = filter['id'];
        final title = filter['title'] ?? '(без названия)';
        final isRange = filter['is_range'] ?? false;
        final isMultiple = filter['is_multiple'] ?? false;
        final dataType = filter['data_type'] ?? 'null';
        final style = filter['style'] ?? '?';
        final valuesCount = (filter['values'] as List?)?.length ?? 0;

        print('   ID=$id: "$title"');
        print(
          '      is_range=$isRange, is_multiple=$isMultiple, data_type=$dataType, style=$style',
        );

        if (valuesCount > 0) {
          print('      Values ($valuesCount):');
          for (final val in (filter['values'] as List).take(5)) {
            print('        - ID=${val['id']}: "${val['value']}"');
          }
          if (valuesCount > 5) {
            print('        ... и ещё ${valuesCount - 5}');
          }
        }
      }
    } else {
      print('❌ Ошибка получения фильтров');
      print('   Response: ${filtersResponse.body}');
    }
  } catch (e) {
    print('❌ Исключение при получении фильтров: $e');
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

  // Находим нужные value_id для атрибутов
  int? roomsValueId; // ID значения для "3 комнаты" (атрибут 6)
  int? personTypeValueId; // ID для "Частное лицо" (атрибут 19)

  for (final filter in filters) {
    if (filter['id'] == 6) {
      // Количество комнат - ищем "3"
      final values = filter['values'] as List?;
      if (values != null) {
        for (final v in values) {
          if (v['value'] == '3') {
            roomsValueId = v['id'];
            print('✅ Найден ID для "3 комнаты": $roomsValueId');
            break;
          }
        }
      }
    }

    if (filter['id'] == 19) {
      // Частное лицо / Бизнес
      final values = filter['values'] as List?;
      if (values != null) {
        for (final v in values) {
          if (v['value'] == 'Частное лицо') {
            personTypeValueId = v['id'];
            print('✅ Найден ID для "Частное лицо": $personTypeValueId');
            break;
          }
        }
      }
    }
  }

  // Формируем attributes согласно API
  final Map<String, dynamic> attributes = {
    'value_selected': <int>[],
    'values': <String, dynamic>{},
  };

  // Добавляем Количество комнат (атрибут 6) - ОДНО значение!
  if (roomsValueId != null) {
    attributes['value_selected'].add(roomsValueId);
    print('   Добавлено в value_selected: $roomsValueId (Количество комнат=3)');
  }

  // Добавляем Частное лицо (атрибут 19)
  if (personTypeValueId != null) {
    attributes['value_selected'].add(personTypeValueId);
    print('   Добавлено в value_selected: $personTypeValueId (Частное лицо)');
  }

  // Добавляем Этаж (атрибут 1040) - range
  attributes['values']['1040'] = {'value': 4, 'max_value': 5};
  print('   Добавлено в values[1040]: {value: 4, max_value: 5} (Этаж)');

  // Добавляем Общая площадь (атрибут 1127) - простое поле!
  attributes['values']['1127'] = {'value': 50};
  print('   Добавлено в values[1127]: {value: 50} (Общая площадь)');

  // ⚠️ ВАЖНО: Атрибут 1048 ("Вам предложат цену") ОБЯЗАТЕЛЕН!
  // Он НЕ возвращается API, но ДОЛЖЕН быть в запросе!
  attributes['values']['1048'] = {'value': 1};
  print(
    '   Добавлено в values[1048]: {value: 1} (Вам предложат цену) - REQUIRED!',
  );

  // Формируем полный запрос
  final createRequest = {
    'name': 'Тестовая 3-комнатная квартира, 50 м²',
    'description':
        'Просторная трёхкомнатная квартира в хорошем районе. '
        'Сделан качественный ремонт, установлены новые окна. '
        'Развитая инфраструктура: магазины, школы, детские сады рядом. '
        'Отличная транспортная доступность.',
    'price': '3500000',
    'category_id': 2, // Продажа квартир
    'region_id': mainRegionId ?? 1, // main_region.id
    'address': {
      'region_id': addressRegionId,
      'city_id': cityId,
      'street_id': streetId,
      'building_number': '96',
    },
    'attributes': attributes,
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
      int? advertId;
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

      // ============================================================
      // ШАГ 7: Загрузка изображения
      // ============================================================
      if (advertId != null) {
        print('');
        print('📝 ШАГ 7: Загрузка изображения...');
        print('─────────────────────────────────────────────────────────────');

        // Путь к тестовому изображению
        final imagePath = 'assets/home_page/image.png';
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

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('🏁 ТЕСТ ЗАВЕРШЁН');
  print('═══════════════════════════════════════════════════════════════');
}
