// Тестирование формата фильтров
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

  print('\nФОРМАТИРОВАННЫЕ QUERY PARAMS:');
  final queryParams = <String, dynamic>{};
  filters.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      value.forEach((subKey, subValue) {
        final paramKey = 'filters[$key][$subKey]';
        queryParams[paramKey] = subValue.toString();
        print('  $paramKey = ${subValue.toString()}');
      });
    } else if (value is List) {
      value.forEach((item) {
        final paramKey = 'filters[$key][]';
        queryParams[paramKey] = item.toString();
        print('  $paramKey = ${item.toString()}');
      });
    } else {
      final paramKey = 'filters[$key]';
      queryParams[paramKey] = value.toString();
      print('  $paramKey = ${value.toString()}');
    }
  });

  print('\nИТОГОВЫЙ QUERY STRING:');
  final queryString = queryParams.entries
      .map(
        (e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
      )
      .join('&');
  print('  ?$queryString');

  print('\nПОЛНЫЙ URL:');
  print('  https://api.example.com/adverts?$queryString');
}
