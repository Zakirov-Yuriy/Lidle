import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('User Adverts Pagination Test', () {
    final baseUrl = 'https://dev-api.lidle.io/v1';
    final token =
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwaS5saWR6YS50ZXN0L3YxL2F1dGgvbG9naW4iLCJpYXQiOjE3NTExMDM4NzIsImV4cCI6MTc1MTEwNzQ3MiwibmJmIjoxNzUxMTAzODcyLCJqdGkiOiJHd2tidlhXNmV5bVZ4Mk5yIiwic3ViIjoiMSIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.iJ0fH_lXmsSYWDX-XN713q7x6pLHfg0qoMb44dCvg60';

    test('Get all user adverts with pagination', () async {
      // Тестируем получение всех объявлений пользователя
      var page = 1;
      var allAdverts = <Map<String, dynamic>>[];
      var hasMorePages = true;

      while (hasMorePages) {
        print('=== Запрос страницы $page ===');

        final response = await http.get(
          Uri.parse('$baseUrl/me/adverts?page=$page'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
            'Accept': 'application/json',
            'X-App-Client': 'Postman',
          },
        );

        print('Status code: ${response.statusCode}');
        print('Response body length: ${response.body.length}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('Response data keys: ${data.keys}');

          if (data.containsKey('data')) {
            final adverts = data['data'] as List;
            print('Adverts on page $page: ${adverts.length}');

            // Добавляем объявления с текущей страницы
            for (var advert in adverts) {
              allAdverts.add(advert as Map<String, dynamic>);
            }

            // Проверяем пагинацию
            if (data.containsKey('meta') && data['meta'] != null) {
              final meta = data['meta'];
              final currentPage = meta['current_page'] as int;
              final lastPage = meta['last_page'] as int;
              final total = meta['total'] as int;

              print(
                'Current page: $currentPage, Last page: $lastPage, Total: $total',
              );

              if (currentPage >= lastPage) {
                hasMorePages = false;
                print('Достигнута последняя страница');
              } else {
                page++;
              }
            } else {
              hasMorePages = false;
              print('Нет метаданных пагинации');
            }
          } else {
            print('Нет поля data в ответе');
            hasMorePages = false;
          }
        } else {
          print('Ошибка запроса: ${response.statusCode}');
          print('Response body: ${response.body}');
          hasMorePages = false;
        }
      }

      print('=== Результат ===');
      print('Всего объявлений: ${allAdverts.length}');

      // Выводим информацию о каждом объявлении
      for (int i = 0; i < allAdverts.length; i++) {
        final advert = allAdverts[i];
        print(
          'Объявление ${i + 1}: id=${advert['id']}, name=${advert['name']}, price=${advert['price']}, created_at=${advert['created_at']}',
        );
      }
    });

    test('Get user adverts without pagination parameters', () async {
      print('=== Запрос без параметров пагинации ===');

      final response = await http.get(
        Uri.parse('$baseUrl/me/adverts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept': 'application/json',
          'X-App-Client': 'Postman',
        },
      );

      print('Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Response data keys: ${data.keys}');

        if (data.containsKey('data')) {
          final adverts = data['data'] as List;
          print('Adverts count: ${adverts.length}');

          if (data.containsKey('meta') && data['meta'] != null) {
            final meta = data['meta'];
            print('Meta: ${meta.toString()}');
          }
        }
      } else {
        print('Response body: ${response.body}');
      }
    });

    test('Get user adverts with different page sizes', () async {
      final pageSizes = [5, 10, 20, 50];

      for (final pageSize in pageSizes) {
        print('=== Тест с page_size=$pageSize ===');

        final response = await http.get(
          Uri.parse('$baseUrl/me/adverts?page=1&per_page=$pageSize'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
            'Accept': 'application/json',
            'X-App-Client': 'Postman',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data.containsKey('data')) {
            final adverts = data['data'] as List;
            print('Adverts count with page_size=$pageSize: ${adverts.length}');

            if (data.containsKey('meta') && data['meta'] != null) {
              final meta = data['meta'];
              print('Total: ${meta['total']}, Per page: ${meta['per_page']}');
            }
          }
        }
      }
    });
  });
}
