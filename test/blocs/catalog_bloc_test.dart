// ============================================================
// Тесты для CatalogBloc
// Проверяют состояния каталогов, события (props Equatable)
// и базовое поведение без реального API.
//
// Особенности CatalogBloc:
// - Использует Equatable для сравнения State/Event
// - Имеет кеширование в AppCacheService (L1 RAM)
// - При отсутствии кеша и сети → CatalogError
// ============================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lidle/blocs/catalog/catalog_bloc.dart';
import 'package:lidle/blocs/catalog/catalog_event.dart';
import 'package:lidle/blocs/catalog/catalog_state.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/catalog_model.dart';

void main() {
  group('CatalogBloc', () {
    late CatalogBloc catalogBloc;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('catalog_bloc_test_');
      Hive.init(tempDir.path);
      await HiveService.init();
      catalogBloc = CatalogBloc();
    });

    tearDown(() async {
      catalogBloc.close();
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    // ─── Начальное состояние ───────────────────────────────

    test('начальное состояние равно CatalogInitial', () {
      expect(catalogBloc.state, isA<CatalogInitial>());
    });

    // ─── LoadCatalogs структурные тесты ────────────────────

    /// Примечание: полноценная проверка загрузки каталогов требует
    /// зарегистрированных Hive-адаптеров для Catalog (они генерируются
    /// через build_runner + @HiveType). Данные тесты проверяют что
    /// событие принимается без синхронных исключений.
    test('LoadCatalogs(forceRefresh: true) добавляется без броска', () {
      expect(
        () => catalogBloc.add(const LoadCatalogs(forceRefresh: true)),
        returnsNormally,
      );
    });

    test('LoadCatalogs() добавляется без броска', () {
      expect(() => catalogBloc.add(const LoadCatalogs()), returnsNormally);
    });

    // ─── Классы событий (Equatable props) ─────────────────

    group('LoadCatalogs', () {
      test('forceRefresh по умолчанию false', () {
        const event = LoadCatalogs();
        expect(event.forceRefresh, isFalse);
      });

      test('forceRefresh = true корректно сохраняется', () {
        const event = LoadCatalogs(forceRefresh: true);
        expect(event.forceRefresh, isTrue);
      });

      test('props содержит forceRefresh', () {
        const event = LoadCatalogs(forceRefresh: true);
        expect(event.props, contains(true));
      });
    });

    group('LoadCatalog', () {
      test('хранит catalogId корректно', () {
        const event = LoadCatalog(42);
        expect(event.catalogId, equals(42));
      });

      test('props содержит catalogId', () {
        const event = LoadCatalog(42);
        expect(event.props, contains(42));
      });
    });

    group('LoadCategory', () {
      test('хранит categoryId корректно', () {
        const event = LoadCategory(99);
        expect(event.categoryId, equals(99));
      });

      test('props содержит categoryId', () {
        const event = LoadCategory(99);
        expect(event.props, contains(99));
      });
    });

    // ─── Классы состояний ──────────────────────────────────

    group('CatalogError', () {
      test('хранит сообщение об ошибке корректно', () {
        const state = CatalogError('Ошибка загрузки каталогов');
        expect(state.message, equals('Ошибка загрузки каталогов'));
      });

      test('Equatable props содержит message', () {
        const state = CatalogError('Test error');
        expect(state.props, contains('Test error'));
      });

      test('два CatalogError с одинаковым сообщением равны', () {
        const s1 = CatalogError('msg');
        const s2 = CatalogError('msg');
        expect(s1, equals(s2));
      });

      test('два CatalogError с разными сообщениями не равны', () {
        const s1 = CatalogError('msg1');
        const s2 = CatalogError('msg2');
        expect(s1, isNot(equals(s2)));
      });
    });

    group('CatalogsLoaded', () {
      test('хранит список каталогов корректно', () {
        final catalog = Catalog(
          id: 1,
          name: 'Тест',
          thumbnail: 'assets/test.png',
          slug: 'test-slug',
          type: CatalogType(id: 1, type: 'test'),
        );

        final state = CatalogsLoaded([catalog]);
        expect(state.catalogs, hasLength(1));
        expect(state.catalogs.first.name, equals('Тест'));
      });

      test('Equatable props содержит список каталогов', () {
        final state = CatalogsLoaded(const []);
        expect(state.props, isNotEmpty);
      });
    });

    group('CatalogInitial', () {
      test('является сабклассом CatalogState', () {
        expect(CatalogInitial(), isA<CatalogState>());
      });

      test('два CatalogInitial равны (Equatable)', () {
        expect(CatalogInitial(), equals(CatalogInitial()));
      });
    });

    group('CatalogLoading', () {
      test('является сабклассом CatalogState', () {
        expect(CatalogLoading(), isA<CatalogState>());
      });
    });
  });
}
