// ============================================================
// Тесты для ListingsBloc
// Проверяют состояния объявлений, события, staticListings и
// ветки логики, которые не требуют реального API.
//
// Ключевые принципы тестирования:
// - События фильтрации/поиска/сброса завершаются без эффекта
//   когда состояние НЕ ListingsLoaded (guard return)
// - staticListings содержит ожидаемые данные (тест структуры)
// - State-классы хранят поля корректно
// ============================================================

import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/listings/listings_event.dart';
import 'package:lidle/blocs/listings/listings_state.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/home_models.dart';

void main() {
  group('ListingsBloc', () {
    late ListingsBloc listingsBloc;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('listings_bloc_test_');
      Hive.init(tempDir.path);
      await HiveService.init();
      listingsBloc = ListingsBloc();
    });

    tearDown(() async {
      listingsBloc.close();
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    // ─── Начальное состояние ───────────────────────────────

    test('начальное состояние равно ListingsInitial', () {
      expect(listingsBloc.state, isA<ListingsInitial>());
    });

    // ─── Guard-ветки: return при неверном состоянии ────────

    /// SearchListingsEvent → guard: если state не ListingsLoaded,
    /// обработчик делает return сразу без эмита.
    blocTest<ListingsBloc, ListingsState>(
      'SearchListingsEvent при ListingsInitial → не эмитирует ни одного состояния',
      build: () => ListingsBloc(),
      act: (bloc) => bloc.add(SearchListingsEvent(query: 'квартира')),
      expect: () => <ListingsState>[],
    );

    /// FilterListingsByCategoryEvent → аналогичная guard-ветка
    blocTest<ListingsBloc, ListingsState>(
      'FilterListingsByCategoryEvent при ListingsInitial → не эмитирует ни одного состояния',
      build: () => ListingsBloc(),
      act: (bloc) =>
          bloc.add(FilterListingsByCategoryEvent(categoryId: 'real-estate')),
      expect: () => <ListingsState>[],
    );

    /// ResetFiltersEvent → аналогичная guard-ветка
    blocTest<ListingsBloc, ListingsState>(
      'ResetFiltersEvent при ListingsInitial → не эмитирует ни одного состояния',
      build: () => ListingsBloc(),
      act: (bloc) => bloc.add(ResetFiltersEvent()),
      expect: () => <ListingsState>[],
    );

    // ─── LoadListingsEvent → начинает с ListingsLoading ────

    blocTest<ListingsBloc, ListingsState>(
      'LoadListingsEvent → первое состояние ListingsLoading',
      build: () => ListingsBloc(),
      act: (bloc) => bloc.add(const LoadListingsEvent()),
      wait: const Duration(seconds: 3),
      expect: () => [
        isA<ListingsLoading>(),
        // Следующее состояние зависит от API/Hive — допускаем любое
        isA<ListingsState>(),
      ],
    );

    // ─── staticListings ────────────────────────────────────

    test('staticListings не пустой', () {
      expect(ListingsBloc.staticListings, isNotEmpty);
    });

    test('staticListings содержит объявления с непустыми заголовками', () {
      for (final listing in ListingsBloc.staticListings) {
        expect(listing.title, isNotEmpty);
        expect(listing.id, isNotEmpty);
      }
    });

    test('каждый элемент staticListings имеет imagePath', () {
      for (final listing in ListingsBloc.staticListings) {
        expect(listing.imagePath, isNotEmpty);
      }
    });

    // ─── Классы состояний ──────────────────────────────────

    group('ListingsLoaded', () {
      test('хранит listings, categories и пагинацию корректно', () {
        final listing = Listing(
          id: 'test_1',
          imagePath: 'assets/img.png',
          title: 'Тестовое объявление',
          price: '1 000 000 ₽',
          location: 'Москва',
          date: '01.01.2024',
        );
        const category = Category(
          title: 'Тест',
          color: Colors.blue,
          imagePath: 'assets/cat.png',
        );

        final state = ListingsLoaded(
          listings: [listing],
          categories: [category],
          currentPage: 2,
          totalPages: 5,
          itemsPerPage: 20,
        );

        expect(state.listings, hasLength(1));
        expect(state.categories, hasLength(1));
        expect(state.currentPage, equals(2));
        expect(state.totalPages, equals(5));
        expect(state.itemsPerPage, equals(20));
      });

      test('filteredListings по умолчанию equals listings', () {
        final listing = Listing(
          id: 'test_2',
          imagePath: 'assets/img.png',
          title: 'Объявление',
          price: '500 000 ₽',
          location: 'Питер',
          date: '05.05.2024',
        );

        final state = ListingsLoaded(listings: [listing], categories: const []);
        expect(state.filteredListings, equals(state.listings));
      });
    });

    group('ListingsError', () {
      test('хранит сообщение об ошибке', () {
        final state = ListingsError(message: 'Нет подключения к сети');
        expect(state.message, equals('Нет подключения к сети'));
      });
    });

    group('ListingsSearchResults', () {
      test('хранит результаты и запрос корректно', () {
        final listing = Listing(
          id: 'test_3',
          imagePath: 'assets/img.png',
          title: 'Acura MDX',
          price: '2 000 000 ₽',
          location: 'Брянск',
          date: '01.03.2024',
        );

        final state = ListingsSearchResults(
          searchResults: [listing],
          query: 'Acura',
        );

        expect(state.searchResults, hasLength(1));
        expect(state.query, equals('Acura'));
      });
    });

    group('ListingsFiltered', () {
      test('хранит отфильтрованные объявления и categoryId', () {
        final listing = Listing(
          id: 'test_4',
          imagePath: 'assets/img.png',
          title: 'Квартира 2-к',
          price: '10 000 000 ₽',
          location: 'Москва',
          date: '10.02.2024',
        );

        final state = ListingsFiltered(
          filteredListings: [listing],
          categoryId: 'real-estate',
        );

        expect(state.filteredListings, hasLength(1));
        expect(state.categoryId, equals('real-estate'));
      });
    });

    // ─── Классы событий ───────────────────────────────────

    group('LoadListingsEvent', () {
      test('forceRefresh по умолчанию false', () {
        const event = LoadListingsEvent();
        expect(event.forceRefresh, isFalse);
      });

      test('forceRefresh можно установить в true', () {
        const event = LoadListingsEvent(forceRefresh: true);
        expect(event.forceRefresh, isTrue);
      });
    });

    group('SearchListingsEvent', () {
      test('хранит query корректно', () {
        final event = SearchListingsEvent(query: 'студия');
        expect(event.query, equals('студия'));
      });
    });

    group('FilterListingsByCategoryEvent', () {
      test('хранит categoryId корректно', () {
        final event = FilterListingsByCategoryEvent(categoryId: 'auto');
        expect(event.categoryId, equals('auto'));
      });
    });
  });
}
