import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/models/home_models.dart';

/// Интеграционные тесты для проверки всего потока фильтрации объявлений по имени продавца
void main() {
  group('Seller Profile Name Filtering Integration Tests', () {
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

    /// Имитирует конвертацию Listing в JSON для передачи между экранами
    Map<String, dynamic> listingToJson(Listing listing) {
      return {
        'id': listing.id,
        'image': listing.imagePath,
        'images': listing.images,
        'title': listing.title,
        'price': listing.price,
        'address': listing.location,
        'date': listing.date,
        'isFavorited': listing.isFavorited,
        'description': listing.description,
        'seller': {
          'id': listing.userId,
          'name': listing.sellerName,
          'avatar': listing.sellerAvatar,
          'phone': listing.sellerPhone,
          'registrationDate': listing.sellerRegistrationDate,
        },
        'attributes': {'values': listing.characteristics},
      };
    }

    test('Integration: Listing conversion preserves seller name', () {
      final listing = Listing(
        id: '118',
        imagePath: 'https://example.com/image.jpg',
        title: 'Просторная квартира',
        price: '1000000',
        location: 'Москва',
        date: '26.02.2026',
        sellerName: 'Иван Иванов',
        sellerAvatar: 'https://example.com/avatar.jpg',
        sellerPhone: '+7 (999) 123-45-67',
      );

      final json = listingToJson(listing);

      // Проверяем что имя продавца сохранилось в JSON структуре
      expect(json['seller']['name'], 'Иван Иванов');
      expect(json['id'], '118');
      expect(json['title'], 'Просторная квартира');
    });

    test('Integration: Filter with real API-like response structure', () {
      // Имитируем реальный ответ API переведенный в JSON
      final allListings = [
        {
          'id': '118',
          'date': '25.02.2026',
          'name': 'Просторная одногомнатная квартира',
          'price': '141414.00',
          'address': 'пгт. Александровка, ул. Гагарина',
          'seller': {
            'id': '5',
            'name': 'Иван Иванов',
            'avatar': 'https://dev-img.lidle.io/users/5/avatar.jpg',
            'phone': '+7 (999) 123-45-67',
          },
        },
        {
          'id': '119',
          'date': '25.02.2026',
          'name': 'Двухкомнатная квартира',
          'price': '200000.00',
          'address': 'г. Москва',
          'seller': {
            'id': '5',
            'name': 'Иван Иванов',
            'avatar': 'https://dev-img.lidle.io/users/5/avatar.jpg',
            'phone': '+7 999 123 45 67',
          },
        },
        {
          'id': '120',
          'date': '26.02.2026',
          'name': 'Трехкомнатная квартира',
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

      // Фильтруем по имени первого продавца
      final sellerName = 'Иван Иванов';
      final filtered = filterListingsByName(allListings, sellerName);

      // Должны получить объявления от Ивана Иванова (ID 118 и 119)
      expect(filtered.length, 2);
      expect(filtered[0]['id'], '118');
      expect(filtered[1]['id'], '119');
      expect(filtered[0]['seller']['name'], 'Иван Иванов');
      expect(filtered[1]['seller']['name'], 'Иван Иванов');
    });

    test('Integration: Convert Listing models, then filter', () {
      // Создаем модели Listing
      final listings = [
        Listing(
          id: '118',
          imagePath: 'https://example.com/118.jpg',
          title: 'Квартира 1',
          price: '1000000',
          location: 'Москва',
          date: '25.02.2026',
          sellerName: 'Иван Иванов',
          sellerAvatar: 'https://example.com/ivan.jpg',
          sellerPhone: '+7 (999) 123-45-67',
          userId: '5',
        ),
        Listing(
          id: '119',
          imagePath: 'https://example.com/119.jpg',
          title: 'Квартира 2',
          price: '2000000',
          location: 'Москва',
          date: '26.02.2026',
          sellerName: 'Петр Петров',
          sellerAvatar: 'https://example.com/petr.jpg',
          sellerPhone: '+7 (900) 000-00-00',
          userId: '10',
        ),
      ];

      // Конвертируем в JSON (как это происходит при передаче на SellerProfileScreen)
      final jsonListings = listings.map((l) => listingToJson(l)).toList();

      // Фильтруем по телефону Ивана
      final filtered = filterListingsByPhone(
        jsonListings,
        '+7 (999) 123-45-67',
      );

      // Ожидаем только объявление от Ивана
      expect(filtered.length, 1);
      expect(filtered[0]['seller']['name'], 'Иван Иванов');
      expect(filtered[0]['id'], '118');
    });

    test(
      'Integration: Edge case - seller with no phone in some listings and with phone in others',
      () {
        final allListings = [
          {
            'id': '118',
            'seller': {
              'id': '5',
              'name': 'Иван',
              'phone': '+7 (999) 123-45-67',
            },
          },
          {
            'id': '119',
            'seller': {'id': '5', 'name': 'Иван'}, // No phone
          },
          {
            'id': '120',
            'seller': {
              'id': '5',
              'name': 'Иван',
              'phone': '+7 (999) 123-45-67',
            },
          },
          {
            'id': '121',
            'seller': {
              'id': '10',
              'name': 'Петр',
              'phone': '+7 (900) 000-00-00',
            },
          },
        ];

        final filtered = filterListingsByPhone(
          allListings,
          '+7 (999) 123-45-67',
        );

        // Должны получить только объявления с совпадающим телефоном
        expect(filtered.length, 2);
        expect(filtered[0]['id'], '118');
        expect(filtered[1]['id'], '120');
      },
    );

    test('Integration: Search for seller with Russian formatting of phone', () {
      final allListings = [
        {
          'id': '1',
          'seller': {'name': 'Иван', 'phone': '+7 (989) 343-34-34'},
        },
        {
          'id': '2',
          'seller': {'name': 'Мария', 'phone': '+7 989 343 34 34'},
        },
        {
          'id': '3',
          'seller': {'name': 'Сергей', 'phone': '+79893433434'},
        },
      ];

      final filtered = filterListingsByPhone(allListings, '+7 (989) 343 34-34');

      expect(filtered.length, 3);
    });

    test('Integration: Performance with large dataset (1000+ listings)', () {
      // Создаем большой набор объявлений
      const targetPhone = '+7 (999) 123-45-67';
      final listings = List.generate(
        1000,
        (index) => {
          'id': '$index',
          'seller': {
            'phone': index % 10 == 0
                ? targetPhone
                : '+7 (${index % 900}00) 000-00-00',
          },
        },
      );

      final stopwatch = Stopwatch()..start();
      final filtered = filterListingsByPhone(listings, targetPhone);
      stopwatch.stop();

      // Должны найти 100 объявлений (каждое 10-е)
      expect(filtered.length, 100);
      // Должно быть быстрым даже для 1000 объявлений
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('Integration: Multiple sellers with different phone formats', () {
      // Реальный сценарий с разными продавцами и форматами номеров
      final allListings = [
        // Иван Иванов с разными форматами
        {
          'id': '1',
          'seller': {'name': 'Иван Иванов', 'phone': '+7-999-111-1111'},
        },
        {
          'id': '2',
          'seller': {'name': 'Иван Иванов', 'phone': '+7 999 111 1111'},
        },
        {
          'id': '3',
          'seller': {'name': 'Иван Иванов', 'phone': '+79991111111'},
        },
        // Мария Сергеевна
        {
          'id': '4',
          'seller': {'name': 'Мария Сергеевна', 'phone': '89993332222'},
        },
        // Петр
        {
          'id': '5',
          'seller': {'name': 'Петр', 'phone': '+7 (888) 555-55-55'},
        },
      ];

      // Ищем объявления Ивана
      final ivanListings = filterListingsByPhone(
        allListings,
        '+7 (999) 111-1111',
      );

      expect(ivanListings.length, 3);
      for (final listing in ivanListings) {
        expect(listing['seller']['name'], 'Иван Иванов');
      }

      // Ищем объявления Марии
      final mariaListings = filterListingsByPhone(allListings, '89993332222');

      expect(mariaListings.length, 1);
      expect(mariaListings[0]['id'], '4');
    });
  });
}
