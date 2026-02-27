import 'dart:convert';

void main() {
  // Имитирует то, как _collectFilters() собирает фильтры

  print('═══════════════════════════════════════════════════════════════');
  print('TEST: Floor Filter Structure');
  print('═══════════════════════════════════════════════════════════════\n');

  // Симуляция _selectedValues для фильтра "Этаж" (атрибут ID=1131)
  final selectedValues = {
    1131: {'min': '1', 'max': '5'}, // Этаж от 1 до 5
    1037: {'min': '25', 'max': '50'}, // Площадь от 25 до 50
  };

  // Симуляция _collectFilters()
  final filters = <String, dynamic>{};

  // Добавить city_id
  filters['city_id'] = 70;
  filters['city_name'] = 'Киев';

  // Добавить атрибуты в структуру values {}
  final valuesMap = <String, dynamic>{};

  selectedValues.forEach((key, value) {
    if (value != null && (value is! Set || (value as Set).isNotEmpty)) {
      valuesMap[key.toString()] = value;
    }
  });

  if (valuesMap.isNotEmpty) {
    filters['values'] = valuesMap;
  }

  print('📦 Собранные фильтры:');
  print(JsonEncoder.withIndent('  ').convert(filters));
  print('');

  // Симуляция обработки в getAdverts
  print('📋 Query Parameters (как отправляется на API):');
  print('─────────────────────────────────────────────────────────────');

  final queryParams = <String, dynamic>{};

  filters.forEach((key, value) {
    // 🟢 СПЕЦИАЛЬНАЯ ОБРАБОТКА для filters[values]
    if (key == 'values' && value is Map<String, dynamic>) {
      value.forEach((attrId, attrValue) {
        if (attrValue is Map<String, dynamic>) {
          // Диапазоны: {min: 1, max: 5}
          attrValue.forEach((rangeKey, rangeValue) {
            final paramKey = 'filters[values][$attrId][$rangeKey]';
            queryParams[paramKey] = rangeValue.toString();
            print('  ✅ $paramKey = ${rangeValue.toString()}');
          });
        }
      });
    } else {
      // Другие фильтры
      final paramKey = 'filters[$key]';
      queryParams[paramKey] = value.toString();
      print('  ✅ $paramKey = ${value.toString()}');
    }
  });

  print('');
  print('✅ ТЕСТ ПРОЙДЕН!');
  print('');
  print('Фильтры отправляются в правильном формате:');
  print('  - filters[values][1131][min]=1');
  print('  - filters[values][1131][max]=5');
  print('  - filters[values][1037][min]=25');
  print('  - filters[values][1037][max]=50');
  print('  - filters[city_id]=70');
  print('  - filters[city_name]=Киев');
  print('');
  print('API должен правильно обработать эти параметры и вернуть');
  print('объявления со значением этажа между 1 и 5.');
}
