import 'package:flutter_test/flutter_test.dart';

/// Тесты для фильтрации объявлений по имени продавца
void main() {
  group('Seller Profile Name Filtering Tests', () {
    /// Функция для фильтрации объявлений по имени продавца
    List<Map<String, dynamic>> filterListingsByName(
      List<Map<String, dynamic>> listings,
      String sellerName,
    ) {
      if (sellerName.isEmpty) return [];

      final normalized = sellerName.trim();

      return listings.where((listing) {
        final listingName =
            listing['seller']?['name']?.toString() ??
            listing['sellerName']?.toString() ??
            listing['name']?.toString() ??
            '';

        final normalizedListing = listingName.trim();
        return normalizedListing == normalized;
      }).toList();
    }

    test('FilterByName: Single match - exact name', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'id': '10', 'name': 'Петр Петров'},
        },
      ];

      final filtered = filterListingsByName(listings, 'Иван Иванов');
      expect(filtered.length, 1);
      expect(filtered[0]['id'], '1');
    });

    test('FilterByName: Multiple matches - same seller', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
        {
          'id': '3',
          'title': 'Квартира 3',
          'seller': {'id': '10', 'name': 'Петр Петров'},
        },
      ];

      final filtered = filterListingsByName(listings, 'Иван Иванов');
      expect(filtered.length, 2);
      expect(filtered[0]['id'], '1');
      expect(filtered[1]['id'], '2');
    });

    test('FilterByName: No matches', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'id': '10', 'name': 'Петр Петров'},
        },
      ];

      final filtered = filterListingsByName(listings, 'Мария Сидорова');
      expect(filtered.length, 0);
    });

    test('FilterByName: Empty listings', () {
      final filtered = filterListingsByName([], 'Иван Иванов');
      expect(filtered.length, 0);
    });

    test('FilterByName: Empty seller name', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
      ];

      final filtered = filterListingsByName(listings, '');
      expect(filtered.length, 0);
    });

    test('FilterByName: Seller name with whitespace', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'id': '5', 'name': '  Иван Иванов  '},
        },
      ];

      final filtered = filterListingsByName(listings, 'Иван Иванов');
      expect(filtered.length, 1);
      expect(filtered[0]['id'], '1');
    });

    test('FilterByName: Case sensitive match should work on trim', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'id': '10', 'name': 'иван иванов'},
        },
      ];

      // Case sensitive - должен найтись 1 результат
      final filtered = filterListingsByName(listings, 'Иван Иванов');
      expect(filtered.length, 1);
      expect(filtered[0]['id'], '1');
    });

    test('FilterByName: Fallback to sellerName field', () {
      final listings = [
        {'id': '1', 'title': 'Квартира 1', 'sellerName': 'Иван Иванов'},
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'id': '10', 'name': 'Петр Петров'},
        },
      ];

      final filtered = filterListingsByName(listings, 'Иван Иванов');
      expect(filtered.length, 1);
      expect(filtered[0]['id'], '1');
    });

    test('FilterByName: Large dataset - 1000 listings', () {
      final listings = <Map<String, dynamic>>[];

      // Создаем 1000 объявлений
      for (int i = 0; i < 1000; i++) {
        if (i % 10 == 0) {
          // Каждое 10-е объявление от Ивана Иванова
          listings.add({
            'id': '$i',
            'title': 'Квартира $i',
            'seller': {'id': '5', 'name': 'Иван Иванов'},
          });
        } else {
          listings.add({
            'id': '$i',
            'title': 'Квартира $i',
            'seller': {'id': i, 'name': 'Продавец $i'},
          });
        }
      }

      final stopwatch = Stopwatch()..start();
      final filtered = filterListingsByName(listings, 'Иван Иванов');
      stopwatch.stop();

      expect(filtered.length, 100); // 1000 / 10 = 100
      print('Filtered 1000 listings in ${stopwatch.elapsedMilliseconds}ms');
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
      ); // Должно быть быстро
    });

    test('FilterByName: Real API-like response', () {
      final listings = [
        {
          'id': '118',
          'date': '25.02.2026',
          'title': 'Просторная одногомнатная квартира',
          'price': '141414.00',
          'address': 'пгт. Александровка, ул. Гагарина',
          'seller': {
            'id': '5',
            'name': 'Юрий Зак Зак',
            'avatar': 'https://dev-img.lidle.io/users/5/avatar.jpg',
            'phone': '+7 (999) 123-45-67',
          },
        },
        {
          'id': '119',
          'date': '25.02.2026',
          'title': 'Двухкомнатная квартира',
          'price': '200000.00',
          'address': 'г. Москва',
          'seller': {
            'id': '5',
            'name': 'Юрий Зак Зак',
            'avatar': 'https://dev-img.lidle.io/users/5/avatar.jpg',
            'phone': '+7 999 123 45 67',
          },
        },
        {
          'id': '120',
          'date': '26.02.2026',
          'title': 'Трехкомнатная квартира',
          'price': '300000.00',
          'address': 'г. Санкт-Петербург',
          'seller': {
            'id': '10',
            'name': 'Петр Петров',
            'avatar': 'https://dev-img.lidle.io/users/10/avatar.jpg',
            'phone': '+7 (900) 000-00-00',
          },
        },
      ];

      final filtered = filterListingsByName(listings, 'Юрий Зак Зак');

      expect(filtered.length, 2);
      expect(filtered[0]['id'], '118');
      expect(filtered[1]['id'], '119');
      expect(filtered[0]['seller']['name'], 'Юрий Зак Зак');
      expect(filtered[1]['seller']['name'], 'Юрий Зак Зак');
    });

    test('FilterByName: Multiple sellers, correct filtering', () {
      final listings = [
        {
          'id': '1',
          'title': 'Объявление 1',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
        {
          'id': '2',
          'title': 'Объявление 2',
          'seller': {'id': '10', 'name': 'Петр Петров'},
        },
        {
          'id': '3',
          'title': 'Объявление 3',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
        {
          'id': '4',
          'title': 'Объявление 4',
          'seller': {'id': '15', 'name': 'Мария Сидорова'},
        },
        {
          'id': '5',
          'title': 'Объявление 5',
          'seller': {'id': '10', 'name': 'Петр Петров'},
        },
      ];

      // Фильтруем Ивана
      final ivanFiltered = filterListingsByName(listings, 'Иван Иванов');
      expect(ivanFiltered.length, 2);
      expect(ivanFiltered[0]['id'], '1');
      expect(ivanFiltered[1]['id'], '3');

      // Фильтруем Петра
      final petrFiltered = filterListingsByName(listings, 'Петр Петров');
      expect(petrFiltered.length, 2);
      expect(petrFiltered[0]['id'], '2');
      expect(petrFiltered[1]['id'], '5');

      // Фильтруем Марию
      final mariaFiltered = filterListingsByName(listings, 'Мария Сидорова');
      expect(mariaFiltered.length, 1);
      expect(mariaFiltered[0]['id'], '4');
    });

    test('FilterByName: Null seller should return no match', () {
      final listings = [
        {'id': '1', 'title': 'Объявление 1', 'seller': null},
        {
          'id': '2',
          'title': 'Объявление 2',
          'seller': {'id': '5', 'name': 'Иван Иванов'},
        },
      ];

      final filtered = filterListingsByName(listings, 'Иван Иванов');
      expect(filtered.length, 1);
      expect(filtered[0]['id'], '2');
    });
  });
}
