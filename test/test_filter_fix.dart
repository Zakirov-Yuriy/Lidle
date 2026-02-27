// Тестирование формата фильтров с ИСПРАВЛЕНИЕМ
void main() {
  // Пример фильтров, как они собираются в _collectFilters()
  final Map<String, dynamic> filters = {
    'sort_date': 'new',
    'city_id': 2,
    'attr_1040': 'value1', // Простой фильтр
    'attr_6': ['2', '3', '4'], // Множественный выбор
    'attr_1037': {'min': 1, 'max': 5}, // Диапазон
  };

  print('ВХОДНЫЕ ФИЛЬТРЫ:');
  filters.forEach((key, value) {
    print('  $key: $value (type: ${value.runtimeType})');
  });

  print('\nФОРМАТИРОВАННЫЕ QUERY PARAMS (ИСПРАВЛЕННЫЙ ФОРМАТ):');
  final queryParams = <String, dynamic>{};
  filters.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      value.forEach((subKey, subValue) {
        final paramKey = 'filters[$key][$subKey]';
        queryParams[paramKey] = subValue.toString();
        print('  $paramKey = ${subValue.toString()}');
      });
    } else if (value is List) {
      // ✅ ИСПРАВЛЕНИЕ: используем индексированные ключи [0], [1], [2]
      // вместо [] которые перезаписывали друг друга
      for (int i = 0; i < (value as List).length; i++) {
        final paramKey = 'filters[$key][$i]';
        queryParams[paramKey] = value[i].toString();
        print('  $paramKey = ${value[i].toString()}');
      }
    } else {
      final paramKey = 'filters[$key]';
      queryParams[paramKey] = value.toString();
      print('  $paramKey = ${value.toString()}');
    }
  });

  print('\nИТОГОВЫЙ QUERY STRING (ПРАВИЛЬНЫЙ - все значения присутствуют):');
  final queryString = queryParams.entries
      .map(
        (e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
      )
      .join('&');
  print('  ?$queryString');

  print('\nПОЛНЫЙ URL:');
  print('  https://api.example.com/adverts?$queryString');

  print('\nРАЗДЕКОДИРОВАННЫЙ URL (для чтения):');
  final decodedQueryString = queryParams.entries
      .map((e) => '${e.key}=${e.value}')
      .join('&');
  print('  https://api.example.com/adverts?$decodedQueryString');
}
