// Тест логики фильтров для Ландшафта
void main() {
  // Имитируем данные для Ландшафта (ID 18)
  final landscapeAttributeId = 18;
  final landscapeValues = {
    154: "Река",
    155: "Водохранилище",
    156: "Водопад",
    157: "Озера",
  };

  // Имитируем выбор пользователя: "Река" и "Озера"
  final userSelectedValues = {"Река", "Озера"};

  // Шаг 1: Преобразование в ID (как в _buildStyleDMultipleFilter)
  final selectedIds = <String>{};
  for (var id in landscapeValues.keys) {
    if (userSelectedValues.contains(landscapeValues[id])) {
      selectedIds.add(id.toString());
    }
  }
  print("✅ Шаг 1 - Преобразование в ID: $selectedIds");
  // Ожидаемый результат: {154, 157}

  // Шаг 2: Сохранение в _selectedValues (как в _buildStyleDMultipleFilter)
  final Map<int, dynamic> selectedValues = {};
  selectedValues[landscapeAttributeId] = selectedIds;
  print(
    "✅ Шаг 2 - Сохранение: selectedValues[$landscapeAttributeId] = $selectedIds",
  );
  // Ожидаемый результат: {18: {154, 157}}

  // Шаг 3: Сбор фильтров в _collectFilters()
  final filters = <String, dynamic>{};
  final valueSelectedMap = <String, dynamic>{};

  selectedValues.forEach((key, value) {
    final isValueSelectedType = key < 1000; // 18 < 1000 = true
    print(
      "✅ Шаг 3a - key=$key, isValueSelectedType=$isValueSelectedType, value=$value (type: ${value.runtimeType})",
    );

    if (isValueSelectedType) {
      valueSelectedMap[key.toString()] = value; // "18": {154, 157}
    }
  });

  filters['value_selected'] = valueSelectedMap;
  print("✅ Шаг 3b - Итоговые фильтры: ${filters['value_selected']}");
  // Ожидаемый результат: {"18": {154, 157}}

  // Шаг 4: Преобразование в query параметры (как в ApiService.getAdverts)
  final queryParams = <String, String>{};
  final valueSelected = filters['value_selected'] as Map<String, dynamic>;
  valueSelected.forEach((attrId, attrValue) {
    print(
      "✅ Шаг 4a - attrId=$attrId, attrValue=$attrValue (type: ${attrValue.runtimeType})",
    );

    if (attrValue is Set) {
      final setList = (attrValue as Set).toList();
      print("✅ Шаг 4b - Преобразование Set в List: $setList");
      if (setList.isNotEmpty) {
        for (int i = 0; i < setList.length; i++) {
          final paramKey = 'filters[value_selected][$attrId][$i]';
          queryParams[paramKey] = setList[i].toString();
          print("✅ Шаг 4c - Query параметр: $paramKey = ${setList[i]}");
        }
      }
    }
  });

  // Итоговые query параметры
  print("\n📦 ИТОГОВЫЕ QUERY ПАРАМЕТРЫ:");
  queryParams.forEach((key, value) {
    print("   $key = $value");
  });
  // Ожидаемулат:
  //    filters[value_selected][18][0] = 154
  //    filters[value_selected][18][1] = 157

  print("\n✅ Тест пройден успешно!");
}
