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

  print("=== Получаем все объявления пользователя ===");

  try {
    int page = 1;
    int totalAdverts = 0;
    bool hasMore = true;

    while (hasMore) {
      print("\n--- Страница $page ---");

      final request = await HttpClient().getUrl(
        Uri.parse('$apiUrl?page=$page'),
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

        print("Страница $page:");
        print("  Объявлений на странице: ${adverts.length}");
        print("  Всего объявлений: ${meta['total'] ?? 'N/A'}");
        print("  Текущая страница: ${meta['current_page'] ?? 'N/A'}");
        print("  Последняя страница: ${meta['last_page'] ?? 'N/A'}");

        totalAdverts += adverts.length;
        print("  Накоплено объявлений: $totalAdverts");

        // Проверяем, есть ли еще страницы
        final int currentPage = meta['current_page'] ?? 0;
        final int lastPage = meta['last_page'] ?? 0;

        if (currentPage >= lastPage) {
          hasMore = false;
          print("  Достигнута последняя страница");
        } else {
          page++;
        }

        // Показываем информацию о каждом объявлении
        for (int i = 0; i < adverts.length; i++) {
          final advert = adverts[i];
          print(
            "  Объявление ${i + 1}: ${advert['name']} (ID: ${advert['id']})",
          );
        }
      } else {
        print("Ошибка: ${response.statusCode}");
        print("Ответ: $body");
        hasMore = false;
      }
    }

    print("\n=== Результат ===");
    print("Всего найдено объявлений: $totalAdverts");
  } catch (e) {
    print("Ошибка запроса: $e");
  }
}
