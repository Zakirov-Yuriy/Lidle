import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/listings/listings_event.dart';
import 'package:lidle/blocs/listings/listings_state.dart';
import 'package:bloc_test/bloc_test.dart';

void main() {
  group('ListingsBloc - Pagination Tests', () {
    late ListingsBloc listingsBloc;

    setUp(() {
      listingsBloc = ListingsBloc();
    });

    tearDown(() {
      listingsBloc.close();
    });

    test('Initial state is ListingsInitial', () {
      expect(listingsBloc.state, isA<ListingsInitial>());
    });

    blocTest<ListingsBloc, ListingsState>(
      'emits [ListingsLoading, ListingsLoaded] when LoadListingsEvent is added',
      build: () => listingsBloc,
      act: (bloc) {
        // Загружаем объявления (первые 3 страницы)
        bloc.add(LoadListingsEvent());
      },
      expect: () => [
        isA<ListingsLoading>(),
        isA<ListingsLoaded>(),
      ],
      verify: (bloc) {
        // Проверяем что currentPage = 3 после инициализации
        final state = bloc.state as ListingsLoaded;
        expect(state.currentPage, equals(3),
            reason:
                'currentPage должна быть 3 после загрузки первых 3 страниц');
        expect(state.listings.isNotEmpty, true,
            reason: 'Объявления должны быть загружены');
        expect(state.totalPages, greaterThan(0),
            reason: 'Всего страниц должно быть больше 0');
      },
    );

    blocTest<ListingsBloc, ListingsState>(
      'emits [ListingsLoading, ListingsLoaded] when LoadNextPageEvent is added',
      build: () => listingsBloc,
      seed: () => ListingsLoaded(
        listings: [
          // Симулируем 150 объявлений (3 страницы × 50)
          for (int i = 0; i < 150; i++)
            const home.Listing(
              id: 'listing_1',
              imagePath: 'assets/test.png',
              images: ['assets/test.png'],
              title: 'Test Listing $i',
              price: '100000 ₽',
              location: 'Test Location',
              date: 'Сегодня',
            ),
        ],
        categories: const [],
        currentPage: 3,
        totalPages: 10,
        itemsPerPage: 50,
      ),
      act: (bloc) {
        // Пользователь прокручивает до конца, загружаем следующую страницу
        bloc.add(LoadNextPageEvent());
      },
      expect: () => [
        isA<ListingsLoading>(),
        isA<ListingsLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as ListingsLoaded;
        expect(state.currentPage, equals(4),
            reason: 'currentPage должна быть 4 после загрузки следующей');
        expect(state.listings.length, greaterThan(150),
            reason:
                'Должно быть больше 150 объявлений после загрузки страницы 4');
      },
    );

    blocTest<ListingsBloc, ListingsState>(
      'does not load next page if already on last page',
      build: () => listingsBloc,
      seed: () => ListingsLoaded(
        listings: const [],
        categories: const [],
        currentPage: 10,
        totalPages: 10,
        itemsPerPage: 50,
      ),
      act: (bloc) {
        // Пытаемся загрузить еще страницу, но мы уже на последней
        bloc.add(LoadNextPageEvent());
      },
      expect: () => [],
      verify: (bloc) {
        final state = bloc.state as ListingsLoaded;
        expect(state.currentPage, equals(10),
            reason: 'currentPage не должна измениться на последней странице');
      },
    );

    blocTest<ListingsBloc, ListingsState>(
      'can load specific page',
      build: () => listingsBloc,
      seed: () => ListingsLoaded(
        listings: const [],
        categories: const [],
        currentPage: 3,
        totalPages: 10,
        itemsPerPage: 50,
      ),
      act: (bloc) {
        // Переходим на страницу 7
        bloc.add(LoadSpecificPageEvent(pageNumber: 7));
      },
      expect: () => [
        isA<ListingsLoading>(),
        isA<ListingsLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as ListingsLoaded;
        expect(state.currentPage, equals(7),
            reason: 'currentPage должна быть 7 после перехода');
      },
    );
  });
}

// Импорты
import 'package:lidle/models/home_models.dart' as home;
