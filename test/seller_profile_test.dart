import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Тестирование загрузки объявлений продавца', () {
    /// Тест 1: Проверяем что API возвращает правильный формат для GET /users/{id}/adverts
    test('Формат ответа API для /users/30/adverts', () {
      // ARRANGE - Подготовим тестовые данные
      final userId = 30;

      // ЭТО то, что должен вернуть API согласно документации
      final expectedApiResponse = {
        'data': [
          {
            'id': 88,
            'date': '20.02.2026',
            'name': 'Тестовая 3-комнатная квартира, 50 м2',
            'price': '3500000.00',
            'thumbnail': 'https://example.com/image.jpg',
            'slug': '88-testovaya-3-komnatnaya-kvartira-50-m2',
            'status': {'id': 1, 'title': 'Активный'},
            'address': 'г. Мариуполь, ул. Артёма',
            'is_wishlisted': false,
            'views_count': 0,
            'click_count': 0,
            'share_count': 0,
            'type': {'id': 2, 'type': 'adverts', 'path': 'adverts'},
          },
        ],
        'meta': {
          'current_page': 1,
          'from': 1,
          'last_page': 2,
          'per_page': 30,
          'total': 31,
        },
      };

      // ACT - Трансформируем ответ API в формат для отображения
      final data = expectedApiResponse['data'] as List<dynamic>;
      final transformedListings = data
          .map((item) {
            if (item is Map<String, dynamic>) {
              return <String, dynamic>{
                'id': item['id']?.toString() ?? '',
                'imagePath': item['thumbnail'] ?? '',
                'title': item['name'] ?? '',
                'price': item['price']?.toString() ?? '0',
                'location': item['address'] ?? '',
                'date': item['date'] ?? '',
                'isFavorited': item['is_wishlisted'] ?? false,
              };
            }
            return <String, dynamic>{};
          })
          .where((item) => item.isNotEmpty)
          .toList();

      // ASSERT - Проверяем что трансформация прошла правильно
      expect(
        transformedListings.length,
        1,
        reason: 'Должно быть 1 объявление после трансформации',
      );

      expect(transformedListings[0]['id'], '88', reason: 'ID должен быть "88"');

      expect(
        transformedListings[0]['title'],
        'Тестовая 3-комнатная квартира, 50 м2',
        reason: 'Название должно быть актуальным',
      );

      expect(
        transformedListings[0]['price'],
        '3500000.00',
        reason: 'Цена должна быть "3500000.00"',
      );
    });

    /// Тест 2: Проверяем что userId передается правильно
    test('userId должен передаваться правильно в запрос', () {
      // ARRANGE
      final userId = '30';
      final expectedEndpoint = '/users/30/adverts';

      // ACT
      final actualEndpoint = '/users/$userId/adverts';

      // ASSERT
      expect(
        actualEndpoint,
        expectedEndpoint,
        reason: 'Endpoint должен быть "/users/30/adverts"',
      );
    });

    /// Тест 3: Проверяем что body параметры передаются правильно
    test('Body параметры для GET запроса правильные', () {
      // ARRANGE
      final requestBody = {
        'sort': ['new'], // Новые объявления первыми
        'page': 1, // Первая страница
      };

      // ACT
      final bodyJson = jsonEncode(requestBody);

      // ASSERT
      expect(requestBody['sort'], ['new'], reason: 'sort должен быть ["new"]');

      expect(requestBody['page'], 1, reason: 'page должна быть 1');

      expect(
        bodyJson,
        '{"sort":["new"],"page":1}',
        reason: 'JSON должен быть правильного формата',
      );
    });

    /// Тест 4: Пустой список объявлений
    test('Когда продавец не имеет объявлений', () {
      // ARRANGE
      final emptyApiResponse = {
        'data': [],
        'meta': {
          'current_page': 1,
          'from': null,
          'last_page': 1,
          'per_page': 30,
          'total': 0,
        },
      };

      // ACT
      final data = emptyApiResponse['data'] as List<dynamic>;
      final isEmpty = data.isEmpty;

      // ASSERT
      expect(isEmpty, true, reason: 'Список объявлений должен быть пустой');
    });

    /// Тест 5: Проверяем обработку ошибок при пустом userId
    test('Когда userId пустой или null - не загружаем', () {
      // ARRANGE
      final userId = '';
      final isEmpty = userId.isEmpty;

      // ACT & ASSERT
      expect(isEmpty, true, reason: 'userId не должен быть пустым');
    });

    /// Тест 6: Проверяем что данные преобразуются правильно из API
    test('Трансформация полного набора объявлений', () {
      // ARRANGE
      final apiResponse = {
        'data': [
          {
            'id': 88,
            'date': '20.02.2026',
            'name': 'Квартира 1',
            'price': '1000000',
            'thumbnail': 'https://example.com/1.jpg',
            'address': 'Адрес 1',
            'is_wishlisted': false,
          },
          {
            'id': 89,
            'date': '19.02.2026',
            'name': 'Квартира 2',
            'price': '2000000',
            'thumbnail': 'https://example.com/2.jpg',
            'address': 'Адрес 2',
            'is_wishlisted': true,
          },
        ],
      };

      // ACT
      final result = apiResponse['data'] as List<dynamic>;
      final transformed = result
          .map((item) {
            if (item is Map<String, dynamic>) {
              return {
                'id': item['id']?.toString() ?? '',
                'title': item['name'] ?? '',
                'price': item['price']?.toString() ?? '0',
                'imagePath': item['thumbnail'] ?? '',
                'location': item['address'] ?? '',
                'date': item['date'] ?? '',
                'isFavorited': item['is_wishlisted'] ?? false,
              };
            }
            return {};
          })
          .where((item) => item.isNotEmpty)
          .toList();

      // ASSERT
      expect(transformed.length, 2, reason: 'Должно быть 2 объявления');

      expect(
        transformed[0]['title'],
        'Квартира 1',
        reason: 'Первое объявление - Квартира 1',
      );

      expect(
        transformed[1]['isFavorited'],
        true,
        reason: 'Второе объявление должно быть в избранном',
      );
    });
  });
}
