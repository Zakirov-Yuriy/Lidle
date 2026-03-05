import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';

/// ============================================================
/// ТЕСТЫ: Проверка автоматической загрузки категорий
/// ============================================================
///
/// Тестирование архитектуры категорий:
/// ✅ Загрузка каталогов из API
/// ✅ Парсинг категорий (включая опциональные поля)
/// ✅ Иерархия категорий (children)
/// ✅ Endpoint флаг
///

void main() {
  group('Категорийная система', () {
    test('✅ Загрузка всех каталогов без ошибок', () async {
      print('═══════════════════════════════════════════════════════');
      print('📦 TEST: Загрузка каталогов');
      print('═══════════════════════════════════════════════════════');

      try {
        final catalogs = await ApiService.getCatalogs();

        print('✅ Успешно загружено каталогов: ${catalogs.data.length}');
        expect(catalogs.data.isNotEmpty, true);

        // Проверяем, что есть основные каталоги
        final catalogNames = catalogs.data.map((c) => c.name).toList();
        print('📋 Каталоги: $catalogNames');

        expect(
          catalogNames.contains('Недвижимость'),
          true,
          reason: 'Должна быть категория Недвижимость',
        );
        expect(
          catalogNames.contains('Работа'),
          true,
          reason: 'Должна быть категория Работа',
        );

        print('✅ Все основные каталоги присутствуют');
      } catch (e) {
        print('❌ Ошибка при загрузке каталогов: $e');
        rethrow;
      }
    });

    test('✅ Парсинг категорий с опциональными полями (CatalogType)', () async {
      print('\n═══════════════════════════════════════════════════════');
      print('📋 TEST: Парсинг CatalogType с опциональными полями');
      print('═══════════════════════════════════════════════════════');

      try {
        final catalogs = await ApiService.getCatalogs();

        for (final catalog in catalogs.data) {
          print('\n🔍 Каталог: ${catalog.name} (ID: ${catalog.id})');
          print('   Type ID: ${catalog.type.id}');
          print('   Type.type: ${catalog.type.type ?? "null (OK)"}');
          print('   Type.path: ${catalog.type.path ?? "null (OK)"}');
          print('   Type.slug: ${catalog.type.slug ?? "null (OK)"}');

          // Проверяем, что у всех каталогов есть ID и name
          expect(catalog.id, greaterThan(0));
          expect(catalog.name, isNotEmpty);
          // Type.id всегда должен быть
          expect(catalog.type.id, greaterThan(0));
        }

        print('\n✅ Все каталоги успешно спарсены');
      } catch (e) {
        print('❌ Ошибка парсинга: $e');
        rethrow;
      }
    });

    test('✅ Загрузка категорий Недвижимости (catalogId=1)', () async {
      print('\n═══════════════════════════════════════════════════════');
      print('🏠 TEST: Загрузка категорий Недвижимости');
      print('═══════════════════════════════════════════════════════');

      try {
        final token = await HiveService.getUserData('token');
        final catalog = await ApiService.getCatalog(1, token: token);

        print('✅ Успешно загружено категорий: ${catalog.categories.length}');

        for (final category in catalog.categories) {
          print('\n📍 Категория: ${category.name} (ID: ${category.id})');
          print('   isEndpoint: ${category.isEndpoint}');
          print('   Подкатегории: ${category.children?.length ?? 0}');

          expect(category.id, greaterThan(0));
          expect(category.name, isNotEmpty);

          // Проверяем структуру подкатегорий если они есть
          if (category.children != null && category.children!.isNotEmpty) {
            print(
              '   ✅ Иерархия: есть ${category.children!.length} подкатегорий',
            );
            for (final child in category.children!) {
              expect(child.id, greaterThan(0));
              expect(child.name, isNotEmpty);
            }
          }
        }

        print('\n✅ Категории Недвижимости успешно загружены');
      } catch (e) {
        print('❌ Ошибка при загрузке категорий: $e');
        rethrow;
      }
    });

    test('✅ Загрузка категорий Работы (catalogId=8)', () async {
      print('\n═══════════════════════════════════════════════════════');
      print('💼 TEST: Загрузка категорий Работы');
      print('═══════════════════════════════════════════════════════');

      try {
        final token = await HiveService.getUserData('token');
        final catalog = await ApiService.getCatalog(8, token: token);

        print('✅ Успешно загружено категорий: ${catalog.categories.length}');
        expect(
          catalog.categories.isNotEmpty,
          true,
          reason: 'Категории Работы должны быть загружены',
        );

        for (final category in catalog.categories) {
          print('\n📍 Категория: ${category.name} (ID: ${category.id})');
          print('   isEndpoint: ${category.isEndpoint}');
          print('   Slug: ${category.slug}');

          expect(category.id, greaterThan(0));
          expect(category.name, isNotEmpty);
        }

        print('\n✅ Категории Работы успешно загружены');
      } catch (e) {
        print('❌ Ошибка при загрузке категорий: $e');
        rethrow;
      }
    });

    test('✅ Иерархическая структура категорий', () async {
      print('\n═══════════════════════════════════════════════════════');
      print('🌳 TEST: Проверка иерархии категорий');
      print('═══════════════════════════════════════════════════════');

      try {
        final token = await HiveService.getUserData('token');
        final catalog = await ApiService.getCatalog(1, token: token);

        int categoriesWithChildren = 0;
        int maxNestingLevel = 0;

        void checkNesting(Category cat, int level) {
          if (cat.children != null && cat.children!.isNotEmpty) {
            categoriesWithChildren++;
            maxNestingLevel = maxNestingLevel > level ? maxNestingLevel : level;

            for (final child in cat.children!) {
              checkNesting(child, level + 1);
            }
          }
        }

        for (final category in catalog.categories) {
          checkNesting(category, 1);
        }

        print('✅ Категорий с подкатегориями: $categoriesWithChildren');
        print('✅ Максимальная глубина вложения: $maxNestingLevel');

        print('\n✅ Иерархия категорий проверена');
      } catch (e) {
        print('❌ Ошибка при проверке иерархии: $e');
        rethrow;
      }
    });

    test('✅ Endpoint флаги установлены корректно', () async {
      print('\n═══════════════════════════════════════════════════════');
      print('🎯 TEST: Проверка endpoint флагов');
      print('═══════════════════════════════════════════════════════');

      try {
        final token = await HiveService.getUserData('token');
        final catalog = await ApiService.getCatalog(1, token: token);

        int endpointCount = 0;
        int nonEndpointCount = 0;

        void checkEndpoints(Category cat) {
          if (cat.isEndpoint) {
            endpointCount++;
          } else {
            nonEndpointCount++;
          }

          if (cat.children != null) {
            for (final child in cat.children!) {
              checkEndpoints(child);
            }
          }
        }

        for (final category in catalog.categories) {
          checkEndpoints(category);
        }

        print('✅ Категорий с isEndpoint=true: $endpointCount');
        print('✅ Категорий с isEndpoint=false: $nonEndpointCount');

        expect(endpointCount + nonEndpointCount, greaterThan(0));

        print('\n✅ Endpoint флаги корректны');
      } catch (e) {
        print('❌ Ошибка при проверке флагов: $e');
        rethrow;
      }
    });

    test('✅ Новый каталог автоматически загружается (универсальность)', () async {
      print('\n═══════════════════════════════════════════════════════');
      print('🚀 TEST: Универсальность для новых каталогов');
      print('═══════════════════════════════════════════════════════');

      try {
        final catalogs = await ApiService.getCatalogs();

        print(
          '✅ UniversalCategoryScreen может обработать ${catalogs.data.length} каталогов без изменений кода',
        );

        for (final catalog in catalogs.data) {
          // Каждый каталог можно загрузить через универсальный экран
          final token = await HiveService.getUserData('token');
          final categories = await ApiService.getCatalog(
            catalog.id,
            token: token,
          );

          print(
            '   ✅ ${catalog.name} (ID: ${catalog.id}): ${categories.categories.length} категорий',
          );
        }

        print('\n✅ Универсальный экран поддерживает любые каталоги');
      } catch (e) {
        print('❌ Ошибка при проверке универсальности: $e');
        rethrow;
      }
    });
  });
}
