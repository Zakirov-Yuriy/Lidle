import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('\n' + '='*80);
  print('🔍 АНАЛИЗ: ПОЧЕМУ ЭТИ 5 ФИЛЬТРОВ НЕ РАБОТАЮТ?');
  print('='*80);

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    print('\n[ШАГ 1] Загружаем все фильтры для категории 2...');
    
    final response = await http.get(
      Uri.parse('$baseUrl/meta/filters?category_id=2'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      print('❌ Ошибка API: ${response.statusCode}');
      return;
    }

    final dynamic jsonData = jsonDecode(response.body);
    
    if (jsonData is! Map || jsonData['data'] is! Map) {
      print('❌ Неожиданный формат ответа');
      return;
    }

    final data = jsonData['data'] as Map;
    final filterListDyn = data['filters'];
    
    if (filterListDyn is! List) {
      print('❌ Фильтры не найдены');
      return;
    }

    final filterList = filterListDyn as List;
    print('✅ Загружено ${filterList.length} фильтров\n');

    // Анализируем проблемные фильтры
    print('-'*80);
    print('📋 ПРОБЛЕМНЫЕ ФИЛЬТРЫ:');
    print('-'*80);

    final problematicIds = [6, 14, 17, 18];

    for (final id in problematicIds) {
      try {
        final attr = filterList.firstWhere(
          (a) => (a is Map && a['id'] == id),
          orElse: () => null,
        );

        if (attr != null && attr is Map) {
          final title = attr['title'] ?? 'Unknown';
          final isMultiple = attr['is_multiple'] ?? false;
          final valueList = attr['values'] is List ? (attr['values'] as List) : [];
          
          print('\n✅ ID=$id: "$title"');
          print('   └─ is_multiple: $isMultiple');
          print('   └─ values count: ${valueList.length}');
          
          if (valueList.isNotEmpty && valueList.length <= 3) {
            for (final v in valueList) {
              if (v is Map) {
                print('      ├─ ${v['id']}: "${v['value']}"');
              }
            }
          } else if (valueList.isNotEmpty) {
            final first3 = valueList.take(3);
            for (final v in first3) {
              if (v is Map) {
                print('      ├─ ${v['id']}: "${v['value']}"');
              }
            }
            print('      └─ ... и еще ${valueList.length - 3}');
          }
        } else {
          print('\n❌ ID=$id: НЕ НАЙДЕНО');
        }
      } catch (e) {
        print('\n❌ ID=$id: ОШИБКА - $e');
      }
    }

    // Ищем похожие фильтры
    print('\n' + '-'*80);
    print('🔎 ПОИСК: Бытовая техника и Мультимедиа');
    print('-'*80);

    final keywords = ['техника', 'бытов', 'медиа', 'мультим', 'комфорт'];
    var foundAny = false;

    for (final keyword in keywords) {
      final matches = filterList.where((a) {
        if (a is! Map) return false;
        final title = a['title'] as String?;
        return title?.toLowerCase().contains(keyword) ?? false;
      }).toList();

      if (matches.isNotEmpty) {
        foundAny = true;
        print('\n📌 Поиск по "$keyword":');
        for (final match in matches) {
          if (match is Map) {
            print('   ├─ ID=${match['id']}: "${match['title']}"');
          }
        }
      }
    }

    if (!foundAny) {
      print('\n⚠️  Похожих фильтров не найдено');
    }

    print('\n' + '='*80);
    print('✅ АНАЛИЗ ЗАВЕРШЕН');
    print('='*80 + '\n');

  } catch (e) {
    print('❌ Ошибка: $e');
  }
}
