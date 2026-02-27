import 'dart:convert';

/// Тест структуры фильтра для "Количество комнат"
/// Помогает понять, какой ID атрибута и как его отправлять на API

void main() {
  print('═' * 80);
  print('TEST: Room (Количество комнат) Filter Structure');
  print('═' * 80);

  // Из предыдущих тестов мы знаем что:
  // 6: "Количество комнат"
  // 101: "1 комната"
  // 102: "2 комнаты"
  // 103: "3 комнаты"
  // 104: "4 комнаты"
  // 105: "5+ комнат"

  print('\n[STEP 1] User selects 2 rooms');
  print('-' * 80);
  print('На UI: пользователь выбирает "2 комнаты"');
  print('Выбранное значение: 102 (VALUE_ID для "2 комнаты")');

  // Вероятная структура в _selectedValues после выбора:
  final selectedValues = {
    6: {'102'}, // Set<String> с ID выбранного значения (как текущий код)
  };

  print('\n[STEP 2] _collectFilters() processing');
  print('-' * 80);
  print('Текущий код обрабатывает данные как:');
  print('  filters[values][6] = {"102"}');
  print('  (отправляет как Set)');

  // Но API ожидает разные структуры для value_selected vs values!
  print('\n[STEP 3] API EXPECTATIONS');
  print('-' * 80);

  print('\n✗ НЕПРАВИЛЬНО (текущий код):');
  print('''
API Query Parameters:
  filters[values][6][0] = "102"
  
Это работает для диапазонов (1040 - этаж), но не для value_selected!
  ''');

  print('✓ ПРАВИЛЬНО (как должно быть):');
  print('''
API Query Parameters:
  filters[value_selected][6][0] = "102"
  
Фильтры для value_selected должны использовать ключ "value_selected", а не "values"!
  ''');

  print('\n[STEP 4] JSON структура для API');
  print('-' * 80);

  final correctPayload = {
    'catalog_id': 1,
    'filters': {
      'value_selected': {
        '6': [102], // Атрибут 6 (Комнаты), выбранное значение 102
      },
      'values': {
        '1040': {'min': 1, 'max': 5}, // Диапазон этажей
      },
    },
  };

  print('Правильная структура для API:');
  print(jsonEncode(correctPayload));

  print('\n[STEP 5] РЕШЕНИЕ');
  print('-' * 80);
  print('''
1. В _collectFilters() нужно разделить атрибуты на две категории:
   - value_selected: атрибуты которые имеют конкретные значения (ID)
   - values: диапазоны (min/max)

2. Сейчас нельзя определить это просто по типу значения (Set/Map).
   Нужно либо:
   a) Загрузить metadata и определить тип каждого атрибута при загрузке
   b) Добавить информацию о типе в модель Attribute
   c) Использовать соглашение о номерах ID:
      - ID < 1000: value_selected
      - ID > 1000: values (диапазоны)

3. В api_service.dart нужно обновить обработку для:
   filters[value_selected][attr_id][0], [1], [2] и т.д.
  ''');

  // Проверим номера ID
  print('\n[ANALYSIS OF ATTRIBUTE IDS]');
  print('-' * 80);

  const attributeIds = {
    'value_selected': [6, 14, 17, 19, 101, 102, 103, 104, 105],
    'values (range)': [1040, 1037, 1039, 1127, 1048],
  };

  attributeIds.forEach((type, ids) {
    print('$type:');
    final ranges = ids.asMap().entries;
    var minId = ids.first, maxId = ids.first;
    for (var id in ids) {
      if (id < minId) minId = id;
      if (id > maxId) maxId = id;
    }
    print('  IDs: ${ids.join(", ")}');
    print('  Range: $minId - $maxId');
  });

  print('\n✗ ВЫВОД: Разделение по ID не работает.');
  print('   Нужно добавить информацию о типе в API или модель.');

  print('\n' + '═' * 80);
}
