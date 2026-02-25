import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // Используем токен из debug_token.dart
  const String token =
      "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MjAwMjM4MywiZXhwIjoxNzcyMDA1OTgzLCJuYmYiOjE3NzIwMDIzODMsImp0aSI6ImxmQmt0ZDR1aGJveWpsUUQiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.e6tJXvI-hLqTI3siyHlQRrUwdX7s1FwMdvCBThq-mE4";

  print("=== Тестируем API для получения всех объявлений ===");
  print("Token: $token");
  print("");

  // Тестируем получение всех объявлений пользователя
  await testGetAllUserAdverts(token);
}

Future<void> testGetAllUserAdverts(String token) async {
  const String apiUrl = 'https://dev-api.lidle.io/v1/me/adverts';

  print("=== Получаем все объявления пользователя по всем статусам ===");

  // Статусы объявлений: 1 - Активные, 2 - Неактивные, 3 - На модерации, 8 - Архив
  final List<int> statusIds = [1, 2, 3, 8];
  final Map<int, String> statusNames = {
    1: 'Активные',
    2: 'Неактивные',
    3: 'На модерации',
    8: 'Архив',
  };

  int totalAdverts = 0;

  for (final statusId in statusIds) {
    print("\n--- Статус: ${statusNames[statusId]} (ID: $statusId) ---");

    try {
      int page = 1;
      bool hasMore = true;
      int statusTotal = 0;

      while (hasMore) {
        print("  Страница $page...");

        final request = await HttpClient().getUrl(
          Uri.parse('$apiUrl?page=$page&advert_status_id=$statusId'),
        );
        request.headers.set('Authorization', 'Bearer $token');
        request.headers.set(
          'Accept-Language',
          'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        );
        request.headers.set('Accept', 'application/json');
        request.headers.set('X-App-Client', 'Postman');

        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(body);
          final List<dynamic> adverts = data['data'] ?? [];
          final Map<String, dynamic> meta = data['meta'] ?? {};

          print("    Объявлений на странице: ${adverts.length}");
          print("    Всего объявлений в статусе: ${meta['total'] ?? 'N/A'}");

          statusTotal += adverts.length;
          totalAdverts += adverts.length;

          // Проверяем, есть ли еще страницы
          final int currentPage = meta['current_page'] ?? 0;
          final int lastPage = meta['last_page'] ?? 0;

          if (currentPage >= lastPage) {
            hasMore = false;
            print("    Достигнута последняя страница");
          } else {
            page++;
          }

          // Показываем информацию о каждом объявлении
          for (int i = 0; i < adverts.length; i++) {
            final advert = adverts[i];
            print(
              "    Объявление ${i + 1}: ${advert['name']} (ID: ${advert['id']}) - ${advert['price']} руб.",
            );
          }
        } else {
          print("    Ошибка: ${response.statusCode}");
          print("    Ответ: $body");
          hasMore = false;
        }
      }

      print(
        "  Всего объявлений в статусе '${statusNames[statusId]}': $statusTotal",
      );
    } catch (e) {
      print("  Ошибка при получении объявлений со статусом $statusId: $e");
    }
  }

  print("\n=== Результат ===");
  print("Всего найдено объявлений по всем статусам: $totalAdverts");
}
