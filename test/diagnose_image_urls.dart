import 'dart:io';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

/// Диагностический скрипт для проверки готовых image URLs из API
void main() async {
  print('═══════════════════════════════════════════════════════');
  print('🔍 ДИАГНОСТИКА IMAGE URLs');
  print('═══════════════════════════════════════════════════════\n');

  try {
    // 1. ПОЛУЧИТЬ КАТАЛОГИ
    print('📥 Загружаю каталоги с API...');
    final catalogsResponse = await ApiService.getCatalogs(
      token: TokenService.currentToken,
    );

    print('✅ Получено ${catalogsResponse.data.length} каталогов\n');

    // 2. ПОКАЗАТЬ ПЕРВЫЕ URLS
    print('🖼️  URLS КАТЕГОРИЙ (первые 5):');
    print('─────────────────────────────');
    for (int i = 0; i < catalogsResponse.data.take(5).length; i++) {
      final catalog = catalogsResponse.data[i];
      print('[$i] ${catalog.name}');
      print('    URL: ${catalog.thumbnail}');
      print('');
    }

    // 3. ЕСЛИ ЕСТЬ ПОД-КАТЕГОРИИ - ПОКАЗАТЬ ИХ
    if (catalogsResponse.data.isNotEmpty) {
      final firstCatalog = catalogsResponse.data[0];
      try {
        print('\n📂 ЗАГРУЖАЮ КАТАЛОГ: ${firstCatalog.name}');
        final fullCatalog = await ApiService.getCatalog(firstCatalog.id);
        
        print('✅ Получен каталог с ${fullCatalog.categories.length} категориями\n');
        
        print('🖼️  URLS ПОД-КАТЕГОРИЙ (первые 5):');
        print('─────────────────────────────');
        
        int count = 0;
        void showCategories(List<dynamic> categories) {
          for (final cat in categories) {
            if (count >= 5) return;
            print('[$count] ${cat.name}');
            print('    Thumbnail: ${cat.thumbnail}');
            print('    isEndpoint: ${cat.isEndpoint}');
            print('');
            count++;
            
            if (cat.children != null && cat.children is List) {
              showCategories(cat.children as List);
            }
          }
        }
        
        showCategories(fullCatalog.categories);
      } catch (e) {
        print('❌ Ошибка при загрузке каталога: $e');
      }
    }

    // 4. ПОЛУЧИТЬ ОБЪЯВЛЕНИЯ
    print('\n\n📢 ЗАГРУЖАЮ ОБЪЯВЛЕНИЯ...');
    final advertsResponse = await ApiService.getAdverts(
      token: TokenService.currentToken,
      catalogId: 1,
      page: 1,
      limit: 5,
    );

    print('✅ Получено ${advertsResponse.data.length} объявлений\n');
    
    print('🖼️  URLS ОБЪЯВЛЕНИЙ (первые 5):');
    print('─────────────────────────────');
    for (int i = 0; i < advertsResponse.data.take(5).length; i++) {
      final advert = advertsResponse.data[i];
      print('[$i] ${advert.title}');
      print('    Thumbnail: ${advert.thumbnail}');
      print('');
    }

    // 5. ТЕСТ ПОДКЛЮЧЕНИЯ К CDN
    print('\n\n🌐 ТЕСТ ПОДКЛЮЧЕНИЯ К CDN');
    print('─────────────────────────────');
    
    final imageUrl = catalogsResponse.data.first.thumbnail;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      print('Пытаюсь скачать: $imageUrl');
      try {
        final httpClient = HttpClient();
        final request = await httpClient.headUrl(Uri.parse(imageUrl));
        final response = await request.close();
        
        print('✅ Статус: ${response.statusCode}');
        print('   Content-Length: ${response.contentLength}');
      } catch (e) {
        print('❌ Ошибка: $e');
      }
    }

  } catch (e) {
    print('❌ ОШИБКА: $e');
  }
}
