import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/services/api_service.dart';
import 'dart:io';

/// Тест для диагностики ошибки "Атрибут не принадлежит выбранной категории"
///
/// Этот тест поможет понять:
/// 1. Какие атрибуты загружаются для категории
/// 2. Какие атрибуты отправляются на API
/// 3. Какой атрибут вызывает ошибку 422
///
/// ВАЖНО: Для запуска этого теста нужно установить переменную окружения:
/// set LIDLE_TEST_TOKEN=ваш_токен_здесь
/// flutter test test/diagnose_category_attributes.dart
String? _getTestToken() {
  // Пытаемся получить токен из переменной окружения
  final envToken = Platform.environment['LIDLE_TEST_TOKEN'];
  if (envToken != null && envToken.isNotEmpty) {
    return envToken;
  }
  return null;
}

void main() {
  group('Diagnose Category Attributes Validation Error', () {
    test('List all attributes for category by ID', () async {
      // Ищем категорию "Оператор ПК" в каталоге "Работа"
      // Сначала нужно найти ID этой категории

      final token = _getTestToken();
      if (token == null) {
        print('');
        print('❌ ERROR: No token available.');
        print('');
        print('📝 Для запуска этого теста требуется токен авторизации.');
        print('');
        print('Способ 1 (Windows PowerShell):');
        print('  \$env:LIDLE_TEST_TOKEN = "ваш_токен_здесь"');
        print('  flutter test test/diagnose_category_attributes.dart');
        print('');
        print('Способ 2 (Windows cmd.exe):');
        print('  set LIDLE_TEST_TOKEN=ваш_токен_здесь');
        print('  flutter test test/diagnose_category_attributes.dart');
        print('');
        print('Способ 3 (Linux/Mac):');
        print('  export LIDLE_TEST_TOKEN=ваш_токен_здесь');
        print('  flutter test test/diagnose_category_attributes.dart');
        print('');
        print('Чтобы получить токен:');
        print('  1. Запустите приложение: flutter run -d emulator-5554');
        print('  2. Залогиньтесь в приложение');
        print(
          '  3. Откройте DevTools Memory tab или используйте debug_token.dart',
        );
        print('  4. Скопируйте токен из вывода (начинается с "eyJ")');
        print('');
        return;
      }

      print('');
      print('═' * 80);
      print('🔍 ДИАГНОСТИКА: Атрибуты для различных категорий');
      print('═' * 80);
      print('');

      // Проверяем известные категории "Работа":
      // Нужно узнать точный ID категории "Оператор ПК"
      final categoriesToCheck = [
        10, // Типичный ID для категорий в "Работа"
        11, 12, 13, 14, 15, // Другие возможные ID
        100, 101, 102, // Если это другой диапазон
      ];

      for (final categoryId in categoriesToCheck) {
        print('');
        print('📋 КАТЕГОРИЯ ID = $categoryId');
        print('─' * 80);

        try {
          // Загружаем атрибуты через /adverts/create
          final attributes = await ApiService.getAdvertCreationAttributes(
            categoryId: categoryId,
            token: token,
          );

          print('✅ Загружено ${attributes.length} атрибутов:');
          print('');

          for (final attr in attributes) {
            final dataType = attr.dataType ?? 'unknown';
            print(
              '   ID: ${attr.id.toString().padRight(6)} | '
              'Название: ${attr.title.padRight(40)} | '
              'Тип: ${dataType.padRight(10)} | '
              'Обязателен: ${attr.isRequired ? 'ДА' : 'НЕТ'}',
            );
          }
          print('');
        } catch (e) {
          print('⚠️ Ошибка при загрузке: $e');
        }
      }

      print('');
      print('═' * 80);
      print('');
      print('📝 СЛЕДУЮЩИЙ ШАГ:');
      print('Найдите ID категории "Оператор ПК" в выводе выше,');
      print('затем используйте этот ID для более детальной диагностики.');
      print('');
    });

    test('Analyze form data that would be sent to API', () async {
      // После того как нашли ID категории, тестируем здесь
      // Это даст нам понять какие атрибуты собираются в форме

      final token = _getTestToken();
      if (token == null) {
        print('⏭️ Пропуск теста: токен не установлен.');
        return;
      }

      // ВАЖНО: Измените categoryId на ID из предыдущего теста
      const int categoryId = 10; // Замените на реальный ID

      print('');
      print('═' * 80);
      print('📊 АНАЛИЗ: Какие атрибуты будут отправлены');
      print('═' * 80);
      print('');

      try {
        // Загружаем атрибуты
        final loadedAttributes = await ApiService.getAdvertCreationAttributes(
          categoryId: categoryId,
          token: token,
        );

        print(
          '✅ Загружено ${loadedAttributes.length} атрибутов для категории $categoryId',
        );
        print('');

        print('Полный список загруженных атрибутов:');
        print('─' * 80);
        for (final attr in loadedAttributes) {
          print(
            '[${attr.id}] ${attr.title} '
            '(dataType=${attr.dataType}, required=${attr.isRequired}, '
            'style=${attr.style})',
          );
        }
        print('─' * 80);
        print('');

        // Симулируем какие атрибуты попадут в отправку
        print('Атрибуты которые обычно отправляются:');
        print('─' * 80);

        // Пример: обычно отправляются:
        // 1. Area attribute (если есть)
        // 2. Offer price attribute (если есть)
        // 3. Seller type attribute (если есть)
        // 4. Все выбранные пользователем

        print('Проверяем критические атрибуты:');

        // Area
        final areaAttr = loadedAttributes
            .where(
              (a) =>
                  a.title.toLowerCase().contains('площадь') ||
                  a.title.toLowerCase().contains('area'),
            )
            .firstOrNull;
        if (areaAttr != null) {
          print('  ✅ Area: [${areaAttr.id}] ${areaAttr.title}');
        } else {
          print('  ❌ Area attribute not found');
        }

        // Offer price
        final offerPriceAttr = loadedAttributes
            .where((a) => a.title == 'Вам предложат цену')
            .firstOrNull;
        if (offerPriceAttr != null) {
          print(
            '  ✅ Offer Price: [${offerPriceAttr.id}] ${offerPriceAttr.title}',
          );
        } else {
          print(
            '  ⚠️ Offer price attribute not found (может быть нормально для этой катег.)',
          );
        }

        // Seller type
        final sellerTypeAttr = loadedAttributes
            .where(
              (a) =>
                  a.title == 'Тип продавца' ||
                  a.title.toLowerCase().contains('seller'),
            )
            .firstOrNull;
        if (sellerTypeAttr != null) {
          print(
            '  ✅ Seller Type: [${sellerTypeAttr.id}] ${sellerTypeAttr.title}',
          );
        } else {
          print('  ℹ️ Seller type attribute not found');
        }

        print('');
        print('═' * 80);
      } catch (e) {
        print('❌ Error: $e');
      }
    });

    test('Find all available job categories', () async {
      final token = _getTestToken();
      if (token == null) {
        print('⏭️ Пропуск теста: токен не установлен.');
        return;
      }

      print('');
      print('═' * 80);
      print('🔍 ПОД-CATEGОРИИ КАТАЛОГА "Работа"');
      print('═' * 80);
      print('');

      try {
        // Получаем все категории
        final response = await ApiService.get('/categories', token: token);

        if (response['data'] is List) {
          final allCategories = response['data'] as List;

          // Ищем категорию "Работа" и её подкатегории
          print('Все категории:');
          print('');
          for (final cat in allCategories) {
            if (cat is Map<String, dynamic>) {
              final id = cat['id'];
              final name = cat['name'] ?? 'Unknown';
              final hasChildren =
                  cat['children'] != null &&
                  (cat['children'] is List) &&
                  (cat['children'] as List).isNotEmpty;

              print('[ID=$id] $name${hasChildren ? ' (+ подкатегории)' : ''}');

              // Если это категория "Работа" или её содержит, выводим подкатегории
              if (hasChildren &&
                  (name.toString().contains('Работа') ||
                      name.toString().contains('Вакансия') ||
                      name.toString().contains('работ'))) {
                final children = cat['children'] as List;
                for (final child in children) {
                  if (child is Map<String, dynamic>) {
                    print('  └─ [ID=${child['id']}] ${child['name']}');
                  }
                }
              }
            }
          }
        }
        print('');
      } catch (e) {
        print('❌ Error: $e');
      }
    });
  });
}
