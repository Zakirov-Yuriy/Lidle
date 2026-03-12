import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

/// Тест для проверки объявления #142
void main() async {
  try {
    // Инициализируем токен
    TokenService.currentToken = 'test_token';

    // Пытаемся загрузить объявление #142 напрямую
    print('🔍 Проверяем объявление #142...');
    try {
      final advert = await ApiService.getAdvert(142, token: TokenService.currentToken);
      print('✅ Объявление #142 найдено:');
      print('   ID: ${advert.id}');
      print('   Название: ${advert.title}');
      print('   Статус: ${advert.status}');
      print('   Каталог ID: ${advert.catalogId}');
      print('   Дата создания: ${advert.createdAt}');
    } catch (e) {
      print('❌ Ошибка загрузки объявления #142: $e');
    }

    // Теперь ищем объявление в списке всех объявлений
    print('\n🔍 Ищем объявление #142 в каталогах...');
    
    final catalogs = await ApiService.getCatalogs(token: TokenService.currentToken);
    print('📚 Найдено каталогов: ${catalogs.data.length}');

    for (final catalog in catalogs.data) {
      print('\n📂 Каталог: ${catalog.name} (ID: ${catalog.id})');
      
      // Ищем объявление в первых 10 страницах
      for (int page = 1; page <= 10; page++) {
        try {
          final adverts = await ApiService.getAdverts(
            catalogId: catalog.id,
            token: TokenService.currentToken,
            page: page,
            limit: 50,
          );

          print('   Страница $page: ${adverts.data.length} объявлений');

          // Ищем объявление #142
          final found = adverts.data.firstWhere(
            (a) => a.id == 142,
            orElse: () => throw Exception('Не найдено'),
          );

          print('   ✅ Найдено на странице $page!');
          print('      Название: ${found.title}');
          print('      Статус: ${found.status}');
          print('      Дата: ${found.createdAt}');
          return;
        } catch (e) {
          if (page <= 3) {
            // Продолжаем поиск
          } else if (page == 10) {
            print('   ⚠️ Не найдено в первых 10 страницах');
            break;
          }
        }
      }
    }

    print('\n❌ Объявление #142 не найдено ни в одном каталоге');
  } catch (e) {
    print('❌ Критическая ошибка: $e');
  }
}
