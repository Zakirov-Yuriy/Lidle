import 'package:lidle/services/api_service.dart';

// Диагностика: Почему эти фильтры не работают?
// Фильтры которые User указал как не работающие:
// 1. Количество комнат (ID=6)
// 2. Бытовая техника (ID=? - нужна идентификация)
// 3. Мультимедиа (ID=? - нужна идентификация)
// 4. Инфраструктура (ID=17)
// 5. Ландшафт (ID=18)

void main() async {
  print('\n' + '='*80);
  print('🔍 ДИАГНОСТИКА: ПОЧЕМУ ЭТИ ФИЛЬТРЫ НЕ РАБОТАЮТ?');
  print('='*80);

  // Категория 2 = Real Estate / Недвижимость / Продажа квартир
  const categoryId = 2;
  
  print('\n[STEP 1] Загружаем фильтр-атрибуты для категории $categoryId');
  try {
    final attributes = await ApiService.getListingsFilterAttributes(
      categoryId: categoryId,
    );
    
    print('✅ Загружено ${attributes.length} атрибутов');
    
    // Поиск интересующих нас фильтров
    final problematicIds = [6, 14, 17, 18];
    
    print('\n' + '-'*80);
    print('📋 ИНФОРМАЦИЯ О ПРОБЛЕМНЫХ ФИЛЬТРАХ:');
    print('-'*80);
    
    for (final id in problematicIds) {
      final attr = attributes.firstWhere(
        (a) => a.id == id,
        orElse: () => null,
      );
      
      if (attr != null) {
        print('\n🔴 Attribute ID=$id: "${attr.title}"');
        print('   └─ is_multiple: ${attr.isMultiple}');
        print('   └─ is_range: ${attr.isRange}');
        print('   └─ is_special_design: ${attr.isSpecialDesign}');
        print('   └─ is_popup: ${attr.isPopup}');
        print('   └─ is_title_hidden: ${attr.isTitleHidden}');
        print('   └─ style_single: ${attr.styleSingle}');
        print('   └─ values count: ${attr.values.length}');
        
        // Показываем первые 3 значения
        if (attr.values.isNotEmpty) {
          print('   └─ Sample values:');
          for (int i = 0; i < (attr.values.length < 3 ? attr.values.length : 3); i++) {
            final v = attr.values[i];
            print('      ├─ ID=${v.id}: "${v.value}"');
          }
        }
      } else {
        print('\n🟠 Attribute ID=$id: ❌ НЕ НАЙДЕН');
      }
    }
    
    // Ищем атрибуты которые можно спутать с "Бытовая техника" и "Мультимедиа"
    print('\n' + '-'*80);
    print('🔍 ПОИСК ПОХОЖИХ АТРИБУТОВ (Бытовая техника, Мультимедиа):');
    print('-'*80);
    
    final searchKeywords = ['техника', 'бытов', 'медиа', 'мультим', 'комфорт'];
    
    for (final keyword in searchKeywords) {
      final matches = attributes.where((a) => 
        a.title.toLowerCase().contains(keyword.toLowerCase())
      ).toList();
      
      if (matches.isNotEmpty) {
        print('\n🔎 Поиск по "$keyword":');
        for (final attr in matches) {
          print('   ├─ ID=${attr.id}: "${attr.title}" (is_multiple=${attr.isMultiple})');
        }
      }
    }
    
    // Сравнение: ID < 1000 vs >= 1000
    print('\n' + '-'*80);
    print('📊 АНАЛИЗ: СТРУКТУРА ФИЛЬТРОВ');
    print('-'*80);
    
    final valueSel = attributes.where((a) => a.id < 1000).toList();
    final valueRange = attributes.where((a) => a.id >= 1000).toList();
    
    print('\nФильтры ID < 1000 (value_selected) - выбор из предопределенных значений:');
    print('   Количество: ${valueSel.length}');
    for (final attr in valueSel.take(5)) {
      print('   ├─ ID=${attr.id}: "${attr.title}" (is_multiple=${attr.isMultiple})');
    }
    
    print('\nФильтры ID >= 1000 (values) - диапазоны/ranges:');
    print('   Количество: ${valueRange.length}');
    for (final attr in valueRange.take(5)) {
      print('   ├─ ID=${attr.id}: "${attr.title}" (is_range=${attr.isRange})');
    }
    
    // ТЕСТ 1: Проверяем какой формат ожидает API для ID=6
    print('\n' + '-'*80);
    print('🧪 ТЕСТ 1: Попытаемся отфильтровать по ID=6 (Количество комнат)');
    print('-'*80);
    
    final testFilters1 = {
      'value_selected': {
        '6': {'40'} // 1 комната (ID=40)
      }
    };
    
    print('\nТестируем с фильтром:');
    print('  filters = $testFilters1');
    print('\nПреобразование в query параметры (как делается в getAdverts):');
    
    final processedParams = <String, String>{};
    final valueSelected = testFilters1['value_selected'] as Map;
    for (final attrId in valueSelected.keys) {
      final attrValue = valueSelected[attrId];
      if (attrValue is Set) {
        final setList = attrValue.toList();
        for (int i = 0; i < setList.length; i++) {
          final key = 'filters[value_selected][$attrId][$i]';
          processedParams[key] = setList[i].toString();
          print('  ✅ $key = ${setList[i].toString()}');
        }
      }
    }
    
    // Делаем реальный запрос
    print('\nДелаем реальный запрос с этим фильтром...');
    try {
      final response = await ApiService.getAdverts(
        categoryId: categoryId,
        filters: testFilters1,
        limit: 5,
      );
      
      print('✅ Запрос успешен!');
      print('   Получено ${response.data.length} объявлений');
      
      if (response.data.isNotEmpty) {
        print('   IDs: ${response.data.map((a) => a.id).toList()}');
      }
    } catch (e) {
      print('❌ Ошибка: $e');
    }
    
  } catch (e) {
    print('❌ Ошибка при загрузке атрибутов: $e');
  }
  
  print('\n' + '='*80);
  print('✅ ДИАГНОСТИКА ЗАВЕРШЕНА');
  print('='*80 + '\n');
}
