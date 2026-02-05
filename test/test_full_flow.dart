import 'dart:convert';

/// ПОЛНЫЙ ТЕСТОВЫЙ СЦЕНАРИЙ - Эмуляция процесса отправки объявления
///
/// Этот файл показывает ожидаемый результат на каждом этапе
void main() {
  print('='.padRight(80, '='));
  print('ПОЛНАЯ ЭМУЛЯЦИЯ ПРОЦЕССА СОЗДАНИЯ ОБЪЯВЛЕНИЯ');
  print('='.padRight(80, '='));

  // STAGE 1: Пользователь заполняет форму
  print('\n[STAGE 1] Пользователь заполняет форму');
  print('-' * 80);

  final selectedValues = {
    // Множественные выборы
    6: '3', // Количество комнат - значение "3"
    19: 'Частное лицо', // Частное лицо / Бизнес
    17: 'Исторические места', // Инфраструктура
    14: 'Автономное отопление', // Комфорт
    // Диапазоны
    1040: {'min': 4, 'max': 5}, // Этаж
    1127: {'min': 50, 'max': 100}, // Общая площадь
    // Булевы (обязательные)
    1048: true, // Вам предложат цену
  };

  print('Пользователь выбрал:');
  selectedValues.forEach((key, value) {
    print('  $key: $value');
  });

  // STAGE 2: Приложение преобразует в value_selected и values
  print('\n[STAGE 2] Приложение преобразует выбранные значения');
  print('-' * 80);

  // Эмуляция фильтров из API
  final filterOptions = {
    6: [
      MapEntry('Студия', 100),
      MapEntry('1 комната', 101),
      MapEntry('2 комнаты', 102),
      MapEntry('3', 103), // ← Выбрано (VALUE_ID=103)
      MapEntry('4 комнаты', 104),
      MapEntry('5 комнат', 105),
    ],
    19: [
      MapEntry('Частное лицо', 200), // ← Выбрано (VALUE_ID=200)
      MapEntry('Компания', 201),
    ],
    17: [
      MapEntry('Парк', 300),
      MapEntry('Исторические места', 301), // ← Выбрано (VALUE_ID=301)
      MapEntry('Молл', 302),
    ],
    14: [
      MapEntry('Центральное отопление', 400),
      MapEntry('Автономное отопление', 401), // ← Выбрано (VALUE_ID=401)
    ],
  };

  final Map<String, dynamic> attributes = {
    'value_selected': <int>[],
    'values': <String, dynamic>{},
  };
  print('\n✓ Обработка множественных выборов:');
  for (final attributeId in [6, 19, 17, 14]) {
    final selectedValue = selectedValues[attributeId];
    if (selectedValue is String) {
      final options = filterOptions[attributeId] ?? [];
      final matchingOption = options.firstWhere(
        (e) => e.key == selectedValue,
        orElse: () => const MapEntry('', 0),
      );
      if (matchingOption.value != 0) {
        attributes['value_selected'].add(matchingOption.value);
        print(
          '  Attr $attributeId ($selectedValue) → VALUE_ID ${matchingOption.value}',
        );
      }
    }
  }

  // Обработка диапазонов
  print('\n✓ Обработка диапазонов:');
  final ranges = [1040, 1127];
  for (final attrId in ranges) {
    if (selectedValues.containsKey(attrId)) {
      final range = selectedValues[attrId] as Map;
      attributes['values']['$attrId'] = {
        'value': range['min'],
        'max_value': range['max'],
      };
      print(
        '  Attr $attrId → {value: ${range['min']}, max_value: ${range['max']}}',
      );
    }
  }

  // Обработка булевых
  print('\n✓ Обработка булевых:');
  if (selectedValues[1048] == true) {
    attributes['values']['1048'] = true;
    print('  Attr 1048 → true');
  }

  print('\n📊 Структура attributes после обработки:');
  print(jsonEncode(attributes).replaceAll('},', '},\n  '));

  // STAGE 3: Сериализация в JSON
  print('\n[STAGE 3] Сериализация в JSON');
  print('-' * 80);

  final requestJson = {
    'name': 'Трехкомнатная квартира',
    'description': 'Описание квартиры',
    'price': 150000,
    'category_id': 10,
    'region_id': 1,
    'address': 'г. Москва, ул. Пушкина, 10',
    'attributes': attributes,
    'contacts': {'phone': '+79991234567', 'email': 'user@example.com'},
    'is_auto_renew': false,
  };

  print('📤 Полный JSON для отправки:');
  print(jsonEncode(requestJson).replaceAll('},{', '},\n{'));

  // STAGE 4: Отправка на API
  print('\n[STAGE 4] Отправка на API');
  print('-' * 80);

  print('\nPOST /v1/adverts');
  print('Content-Type: application/json');
  print('Authorization: Bearer <token>');
  print('\nBody:');
  print(jsonEncode(requestJson).replaceAll('},{', '},\n{'));

  // STAGE 5: Ожидаемый ответ API
  print('\n[STAGE 5] Ожидаемый ответ API');
  print('-' * 80);

  print('\n✅ УСПЕШНО (201 Created):');
  final successResponse = {
    'success': true,
    'data': {
      'id': 12345,
      'name': 'Трехкомнатная квартира',
      'price': 150000,
      'status': 'active',
    },
  };
  print(jsonEncode(successResponse).replaceAll('},{', '},\n{'));

  print('\n❌ ОШИБКА (422 Validation Error):');
  final errorResponse = {
    'success': false,
    'errors': {
      'attributes': ['Обязательный атрибут "Вам предложат цену" не заполнен.'],
    },
  };
  print(jsonEncode(errorResponse).replaceAll('},{', '},\n{'));

  // ДИАГНОСТИКА
  print('\n\n[ДИАГНОСТИКА] Проверка перед отправкой');
  print('='.padRight(80, '='));

  print('\n✓ Проверка структуры attributes:');
  print(
    '  - value_selected заполнен: ${(attributes['value_selected'] as List).isNotEmpty}',
  );
  print(
    '  - value_selected содержит VALUE_IDs: ${attributes['value_selected']}',
  );
  print('  - values заполнен: ${(attributes['values'] as Map).isNotEmpty}');
  print(
    '  - values содержит ключи: ${(attributes['values'] as Map).keys.toList()}',
  );

  print('\n✓ Проверка типов в values:');
  final values = attributes['values'] as Map;
  print('  - 1040 тип: ${values['1040'].runtimeType}');
  print('  - 1127 тип: ${values['1127'].runtimeType}');
  print('  - 1048 тип: ${values['1048'].runtimeType}');
  print('  - 1048 значение: ${values['1048']} (должно быть: true)');

  print('\n✓ Ключевые проверки:');
  print('  - 1048 это boolean: ${values['1048'] is bool}');
  print('  - 1048 значение true: ${values['1048'] == true}');
  print('  - 1127 это Map: ${values['1127'] is Map}');
  print(
    '  - 1127 имеет value: ${(values['1127'] as Map).containsKey('value')}',
  );
  print(
    '  - 1127 имеет max_value: ${(values['1127'] as Map).containsKey('max_value')}',
  );

  print('\n\n' + '='.padRight(80, '='));
  print('ДИАГНОСТИКА ЗАВЕРШЕНА');
  print('='.padRight(80, '='));
}
