import 'dart:io';
import 'package:lidle/services/api_service.dart';

/// Тест для проверки загрузки всех каталогов с API
///
/// Запускается как:
/// dart test/test_catalogs_loading.dart
Future<void> main() async {
  print('═══════════════════════════════════════════════════════');
  print('🧪 CATALOGS LOADING TEST');
  print('═══════════════════════════════════════════════════════');

  try {
    final response = await ApiService.getCatalogs();

    print('\n✅ Successfully loaded catalogs!');
    print('Total catalogs: ${response.data.length}\n');

    response.data.asMap().forEach((index, catalog) {
      print('┌─ Catalog [$index]');
      print('│  ID: ${catalog.id}');
      print('│  Name: ${catalog.name}');
      print('│  Slug: ${catalog.slug}');
      print('│  Thumbnail: ${catalog.thumbnail ?? 'null'}');
      print('│  Type: ${catalog.type.type}');
      print('│  Type.path: ${catalog.type.path}');
      print('│  Order: ${catalog.order ?? 'null'}');
      print('└─');
    });

    print('\n═══════════════════════════════════════════════════════');
    print('✅ TEST PASSED: All catalogs loaded successfully');
    print('═══════════════════════════════════════════════════════');
  } catch (e) {
    print('\n❌ TEST FAILED');
    print('Error: $e');
    print('═══════════════════════════════════════════════════════');
    exit(1);
  }
}
