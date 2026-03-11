import 'dart:convert';
import 'package:http/http.dart' as http;

/// Диагностический скрипт для проверки структуры объявления 80
/// Это объявление должно содержать атрибут 18 (Ландшафт) с значением 154 (Река)

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('🔍 ДИАГНОСТИКА ОБЪЯВЛЕНИЯ #80');
  print('═══════════════════════════════════════════════════════════\n');

  const baseUrl = 'https://dev-api.lidle.io/v1';
  const advertId = 80;
  const headers = {
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'X-Client-Platform': 'web',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  try {
    // 1. Получаем объявление БЕЗ атрибутов
    print('📥 1️⃣  Запрос объявления БЕЗ атрибутов...\n');
    final response1 = await http.get(
      Uri.parse('$baseUrl/adverts/$advertId'),
      headers: headers,
    );

    if (response1.statusCode == 200) {
      final data1 = jsonDecode(response1.body) as Map<String, dynamic>;
      print('✅ Статус: ${response1.statusCode} OK');
      print('📊 Структура ответа:');
      _printJsonStructure(data1, indent: 0);
    } else {
      print('❌ Ошибка: ${response1.statusCode}');
      print('Ответ: ${response1.body}');
      return;
    }

    print('\n' + '═' * 60 + '\n');

    // 2. Получаем объявление С атрибутами
    print('📥 2️⃣  Запрос объявления С атрибутами...\n');
    final response2 = await http.get(
      Uri.parse('$baseUrl/adverts/$advertId?with=attributes'),
      headers: headers,
    );

    if (response2.statusCode == 200) {
      final data2 = jsonDecode(response2.body) as Map<String, dynamic>;
      print('✅ Статус: ${response2.statusCode} OK');
      
      if (data2['data'] is List) {
        final advert = (data2['data'] as List).first as Map<String, dynamic>;
        print('📊 Полная структура объявления:');
        _printJsonStructure(advert, indent: 0);

        // 3. Анализируем характеристики
        print('\n' + '═' * 60 + '\n');
        print('🔎 АНАЛИЗ ХАРАКТЕРИСТИК:');
        print('─' * 60);

        final characteristics = advert['characteristics'] as Map<String, dynamic>?;
        if (characteristics == null || characteristics.isEmpty) {
          print('❌ НЕТ характеристик в объявлении!');
        } else {
          print(
            '✅ Найдено ${characteristics.length} характеристик:\n',
          );
          characteristics.forEach((attrId, attrValue) {
            print('   🔹 Атрибут ID: $attrId');
            print('      └─ Значение: $attrValue (тип: ${attrValue.runtimeType})');

            // Проверяем ID 18 (Ландшафт)
            if (attrId == '18') {
              print('      ⭐ ДА! Это ID 18 (Ландшафт)');
              if (attrValue is List) {
                print('         └─ Список значений: $attrValue');
                if (attrValue.contains(154) ||
                    attrValue.contains('154') ||
                    attrValue.map((v) => v.toString()).contains('154')) {
                  print('         ✅ Содержит ID 154 (Река)!!!');
                }
              } else if (attrValue is Map) {
                print('         └─ Структура: ${jsonEncode(attrValue)}');
                final valueSelected =
                    (attrValue as Map<String, dynamic>)['value_selected'];
                print('         └─ value_selected: $valueSelected');
              }
            }
            print('');
          });
        }

        // 4. Выводим структуру "как хранит API"
        print('─' * 60);
        print('\n🗂️  ПОЛНАЯ СТРУКТУРА ОБЪЯВЛЕНИЯ:');
        final jsonStr = jsonEncode(advert);
        print(jsonStr);
      }
    } else {
      print('❌ Ошибка: ${response2.statusCode}');
      print('Ответ: ${response2.body}');
    }

    // 5. Тестируем соответствие фильтров
    print('\n' + '═' * 60 + '\n');
    print('🧪 ТЕСТИРОВАНИЕ ФИЛЬТРА:');
    print('─' * 60);
    print('Запрос с фильтром: filters[value_selected][18][0]=154');
    
    final response3 = await http.get(
      Uri.parse('$baseUrl/adverts?category_id=2&filters[value_selected][18][0]=154'),
      headers: headers,
    );

    if (response3.statusCode == 200) {
      final data3 = jsonDecode(response3.body) as Map<String, dynamic>;
      final adverts = data3['data'] as List;
      print('✅ Статус: 200 OK');
      print('Количество найденных объявлений: ${adverts.length}');
      
      if (adverts.isNotEmpty) {
        print('\n📋 Найденные объявления:');
        for (final advert in adverts) {
          final id = (advert as Map<String, dynamic>)['id'];
          final title = advert['title'];
          print('   • ID $id: $title');
        }
        
        // Проверяем, есть ли объявление 80 в результатах
        final found80 = adverts.any((a) => a['id'] == 80 || a['id'] == '80');
        if (found80) {
          print('\n✅ ДА! Объявление #80 НАЙДЕНО В РЕЗУЛЬТАТАХ!');
        } else {
          print('\n❌ НЕТ! Объявление #80 НЕ НАЙДЕНО В РЕЗУЛЬТАТАХ!');
          print('      Это указывает на проблему с фильтром на сервере!');
        }
      } else {
        print('❌ Объявлений не найдено! (но объявление 80 должно быть)');
      }
    } else {
      print('❌ Ошибка: ${response3.statusCode}');
      print('Ответ: ${response3.body}');
    }

    print('\n' + '═' * 60);
    print('✅ ДИАГНОСТИКА ЗАВЕРШЕНА\n');
  } catch (e) {
    print('❌ Ошибка: $e');
    print(e);
  }
}

/// Рекурсивно выводит структуру JSON объекта
void _printJsonStructure(dynamic data, {int indent = 0}) {
  final prefix = '  ' * indent;

  if (data is Map<String, dynamic>) {
    for (final entry in data.entries) {
      if (entry.value is Map || entry.value is List) {
        print('$prefix📁 "${entry.key}": (${entry.value.runtimeType})');
        _printJsonStructure(entry.value, indent: indent + 1);
      } else {
        print(
          '$prefix  • "${entry.key}": ${_truncate(entry.value.toString(), 80)} (${entry.value.runtimeType})',
        );
      }
    }
  } else if (data is List) {
    print('$prefix  ↳ Array with ${data.length} items');
    if (data.isNotEmpty && data.first is Map) {
      print('$prefix  First item:');
      _printJsonStructure(data.first as Map<String, dynamic>, indent: indent + 2);
    }
  }
}

String _truncate(String text, int maxLen) {
  if (text.length <= maxLen) return text;
  return '${text.substring(0, maxLen - 3)}...';
}
