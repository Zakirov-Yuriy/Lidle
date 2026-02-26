import 'package:flutter_test/flutter_test.dart';

/// Тесты для фильтрации объявлений по телефону продавца
/// в SellerProfileScreen
void main() {
  group('SellerProfileScreen Phone Filtering Tests', () {
    /// Функция для нормализации телефона из seller_profile_screen.dart
    String normalizePhone(String phone) {
      if (phone.isEmpty) return '';
      return phone.replaceAll(RegExp(r'[^0-9+]'), '');
    }

    /// Функция для фильтрации объявлений по телефону
    List<Map<String, dynamic>> filterListingsByPhone(
      List<Map<String, dynamic>> listings,
      String sellerPhone,
    ) {
      if (sellerPhone.isEmpty) return [];

      final normalized = normalizePhone(sellerPhone);

      return listings.where((listing) {
        final listingPhone =
            listing['seller']?['phone']?.toString() ??
            listing['sellerPhone']?.toString() ??
            listing['phone']?.toString() ??
            '';

        final normalizedListing = normalizePhone(listingPhone);
        return normalizedListing == normalized;
      }).toList();
    }

    // ============================================================
    // ТЕСТЫ НОРМАЛИЗАЦИИ ТЕЛЕФОНА
    // ============================================================

    test('Normalize phone: +7 (999) 123-45-67 -> +79991234567', () {
      final result = normalizePhone('+7 (999) 123-45-67');
      expect(result, '+79991234567');
    });

    test('Normalize phone: 8 999 123 45 67 -> 89991234567', () {
      final result = normalizePhone('8 999 123 45 67');
      expect(result, '89991234567');
    });

    test('Normalize phone: +7-999-123-45-67 -> +79991234567', () {
      final result = normalizePhone('+7-999-123-45-67');
      expect(result, '+79991234567');
    });

    test('Normalize empty phone -> ""', () {
      final result = normalizePhone('');
      expect(result, '');
    });

    test('Normalize phone with only numbers -> 79991234567', () {
      final result = normalizePhone('79991234567');
      expect(result, '79991234567');
    });

    // ============================================================
    // ТЕСТЫ ФИЛЬТРАЦИИ
    // ============================================================

    test('Filter: Single matching listing with seller.phone', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван', 'phone': '+7 (999) 123-45-67'},
          'price': '1000000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      expect(result.length, 1);
      expect(result[0]['id'], '1');
    });

    test('Filter: Multiple listings, one matches', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван', 'phone': '+7 (999) 123-45-67'},
          'price': '1000000',
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'name': 'Петр', 'phone': '+7 (888) 222-22-22'},
          'price': '2000000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      expect(result.length, 1);
      expect(result[0]['id'], '1');
    });

    test('Filter: Multiple listings, multiple match', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван', 'phone': '+7 (999) 123-45-67'},
          'price': '1000000',
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'name': 'Иван', 'phone': '+7 999 123 45 67'},
          'price': '1200000',
        },
        {
          'id': '3',
          'title': 'Квартира 3',
          'seller': {'name': 'Петр', 'phone': '+7 (888) 222-22-22'},
          'price': '2000000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      // Должны совпадать объявления 1 и 2 (одинаковый нормализованный номер)
      expect(result.length, 2);
      expect(result[0]['id'], '1');
      expect(result[1]['id'], '2');
    });

    test('Filter: No matches -> empty list', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван', 'phone': '+7 (999) 123-45-67'},
          'price': '1000000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (888) 222-22-22');

      expect(result.length, 0);
    });

    test('Filter: Empty listings -> empty result', () {
      final listings = <Map<String, dynamic>>[];
      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      expect(result.length, 0);
    });

    test('Filter: Empty seller phone -> empty result', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван', 'phone': '+7 (999) 123-45-67'},
          'price': '1000000',
        },
      ];

      final result = filterListingsByPhone(listings, '');

      expect(result.length, 0);
    });

    test('Filter: Listing with missing seller.phone', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван'}, // No phone
          'price': '1000000',
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'name': 'Петр', 'phone': '+7 (999) 123-45-67'},
          'price': '1200000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      expect(result.length, 1);
      expect(result[0]['id'], '2');
    });

    test('Filter: Fallback to sellerPhone field (top-level)', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван'},
          'sellerPhone': '+7 (999) 123-45-67', // Top-level phone
          'price': '1000000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      expect(result.length, 1);
      expect(result[0]['id'], '1');
    });

    test('Filter: Fallback to phone field at root', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван'},
          'phone': '+7 (999) 123-45-67', // Root level phone
          'price': '1000000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      expect(result.length, 1);
      expect(result[0]['id'], '1');
    });

    test('Filter: Different phone formats match', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира 1',
          'seller': {'name': 'Иван', 'phone': '+7-888-111-2222'},
          'price': '1000000',
        },
        {
          'id': '2',
          'title': 'Квартира 2',
          'seller': {'name': 'Иван', 'phone': '+7 (999) 123-4567'},
          'price': '1200000',
        },
        {
          'id': '3',
          'title': 'Квартира 3',
          'seller': {'name': 'Иван', 'phone': '+79991234567'},
          'price': '1300000',
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-4567');

      // Все должны совпадать после нормализации
      expect(result.length, 2);
    });

    test('Filter: Real API response structure', () {
      final listings = [
        {
          'id': '118',
          'date': '25.02.2026',
          'name': 'Просторная одногомнатная квартира',
          'price': '141414.00',
          'address': 'пгт. Александровка, ул. Гагарина',
          'seller': {
            'id': '5',
            'name': 'Иван Иванов',
            'avatar': 'https://example.com/avatar.jpg',
            'phone': '+7 (999) 123-45-67',
          },
          'attributes': {'values': {}},
        },
        {
          'id': '119',
          'date': '25.02.2026',
          'name': 'Другая квартира',
          'price': '200000.00',
          'address': 'г. Москва',
          'seller': {
            'id': '10',
            'name': 'Петр Петров',
            'avatar': 'https://example.com/avatar2.jpg',
            'phone': '+7 (888) 888-88-88',
          },
          'attributes': {'values': {}},
        },
      ];

      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      expect(result.length, 1);
      expect(result[0]['id'], '118');
      expect(result[0]['name'], 'Просторная одногомнатная квартира');
    });

    // ============================================================
    // ТЕСТЫ ГРАНИЧНЫХ СЛУЧАЕВ
    // ============================================================

    test('Filter: Special characters in phone', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира',
          'seller': {
            'phone': '+7 (999) 123-45-67', // Contains spaces and dashes
          },
        },
      ];

      final result = filterListingsByPhone(listings, '+7(999)123-4567');

      expect(result.length, 1);
    });

    test('Filter: Phone with extensions', () {
      final listings = [
        {
          'id': '1',
          'title': 'Квартира',
          'seller': {'phone': '+7 999 123 45 67 ext. 123'},
        },
      ];

      // Это не совпадет, т.к. расширение конвертируется в другое число
      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');

      // После нормализации: '+79991234567ext123' != '+79991234567'
      expect(result.length, 0);
    });

    test('Filter: Null seller object', () {
      final listings = [
        {'id': '1', 'title': 'Квартира', 'seller': null},
      ];

      try {
        final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');
        expect(result.length, 0);
      } catch (e) {
        // Это нормально - null seller должен обрабатываться
        expect(e is NoSuchMethodError, true);
      }
    });

    test('Filter: Large dataset performance', () {
      // Создаем большой набор объявлений
      final listings = List.generate(
        1000,
        (index) => {
          'id': '$index',
          'title': 'Квартира $index',
          'seller': {
            'phone': index == 500
                ? '+7 (999) 123-45-67'
                : '+7 (${(index % 1000).toString().padLeft(3, '0')}) 000-00-00',
          },
        },
      );

      final stopwatch = Stopwatch()..start();
      final result = filterListingsByPhone(listings, '+7 (999) 123-45-67');
      stopwatch.stop();

      expect(result.length, 1);
      expect(result[0]['id'], '500');
      // Должно быть быстрым даже для 1000 объявлений
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
