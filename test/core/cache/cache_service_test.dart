import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lidle/core/cache/cache_service.dart';

/// Unit-тесты для [AppCacheService].
///
/// Покрывают:
/// - L1 (RAM): set/get, TTL инвалидация, invalidate, isValid, l1Size
/// - L2 (Hive): persist, L2→L1 промоция при cache-miss в L1
/// - [invalidateByPrefix]: удаление по префиксу из L1 и L2
/// - [clearAll]: полная очистка обоих уровней
void main() {
  late AppCacheService cache;
  late Directory tempDir;

  /// Инициализируем Hive один раз для всей группы тестов.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_cache_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('listingsBox');
  });

  /// Перед каждым тестом очищаем состояние синглтона (L1 + L2).
  setUp(() async {
    cache = AppCacheService();
    await cache.clearAll();
  });

  /// Закрываем Hive и удаляем временную директорию после всех тестов.
  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // L1 (RAM) — базовые операции
  // ══════════════════════════════════════════════════════════════════════════

  group('L1 (RAM) — базовые операции', () {
    test('set/get: возвращает сохранённое значение', () {
      cache.set('key_str', 'hello');
      expect(cache.get<String>('key_str'), equals('hello'));
    });

    test('set/get: хранит числа корректно', () {
      cache.set('key_int', 42);
      expect(cache.get<int>('key_int'), equals(42));
    });

    test('set/get: хранит Map корректно', () {
      cache.set('key_map', {'id': 1, 'name': 'test'});
      expect(cache.get<Map>('key_map'), equals({'id': 1, 'name': 'test'}));
    });

    test('get: возвращает null для несуществующего ключа', () {
      expect(cache.get<String>('missing'), isNull);
    });

    test('l1Size: увеличивается при добавлении записей', () {
      expect(cache.l1Size, equals(0));
      cache.set('a', 1);
      expect(cache.l1Size, equals(1));
      cache.set('b', 2);
      expect(cache.l1Size, equals(2));
    });

    test('set: перезаписывает существующий ключ', () {
      cache.set('dup', 'first');
      cache.set('dup', 'second');
      expect(cache.get<String>('dup'), equals('second'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // L1 — TTL инвалидация
  // ══════════════════════════════════════════════════════════════════════════

  group('L1 — TTL инвалидация', () {
    test('get: возвращает значение до истечения TTL', () async {
      cache.set('ttl_live', 'alive', ttl: const Duration(milliseconds: 200));
      // Читаем сразу — должно быть живо
      expect(cache.get<String>('ttl_live'), equals('alive'));
    });

    test('get: возвращает null после истечения TTL', () async {
      cache.set('ttl_die', 'dead', ttl: const Duration(milliseconds: 50));
      // Ждём истечения TTL
      await Future.delayed(const Duration(milliseconds: 100));
      expect(cache.get<String>('ttl_die'), isNull);
    });

    test('get: удаляет истёкшую запись из L1', () async {
      cache.set('ttl_cleanup', 'val', ttl: const Duration(milliseconds: 50));
      expect(cache.l1Size, equals(1));
      await Future.delayed(const Duration(milliseconds: 100));
      cache.get<String>('ttl_cleanup'); // вызываем get для триггера очистки
      expect(cache.l1Size, equals(0));
    });

    test('isValid: true для актуального ключа', () {
      cache.set('valid_key', 99);
      expect(cache.isValid('valid_key'), isTrue);
    });

    test('isValid: false после истечения TTL', () async {
      cache.set('expired_key', 'temp', ttl: const Duration(milliseconds: 50));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(cache.isValid('expired_key'), isFalse);
    });

    test('isValid: false для несуществующего ключа', () {
      expect(cache.isValid('ghost'), isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // L1 — invalidate
  // ══════════════════════════════════════════════════════════════════════════

  group('L1 — invalidate', () {
    test('invalidate: удаляет ключ из L1', () {
      cache.set('del_key', 'data');
      cache.invalidate('del_key');
      expect(cache.get<String>('del_key'), isNull);
    });

    test('invalidate: не выбрасывает при удалении несуществующего ключа', () {
      expect(() => cache.invalidate('nonexistent'), returnsNormally);
    });

    test('invalidate: не затрагивает другие ключи', () {
      cache.set('keep', 'safe');
      cache.set('remove', 'gone');
      cache.invalidate('remove');
      expect(cache.get<String>('keep'), equals('safe'));
      expect(cache.get<String>('remove'), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // L2 (Hive) — persist и fallback
  // ══════════════════════════════════════════════════════════════════════════

  group('L2 (Hive) — persist и fallback', () {
    test('persist: значение доступно после записи', () {
      cache.set('p_key', 'persisted', persist: true);
      expect(cache.get<String>('p_key'), equals('persisted'));
    });

    test('persist: данные сохраняются в Hive-бокс', () {
      cache.set('hive_direct', 'stored', persist: true);
      // Проверяем наличие записи в Hive напрямую
      final hiveBox = Hive.box<dynamic>('listingsBox');
      expect(hiveBox.containsKey('hive_direct'), isTrue);
      final raw = hiveBox.get('hive_direct') as Map;
      expect(raw['data'], equals('stored'));
    });

    test(
      'L2→L1 промоция: данные из Hive читаются при cache-miss в L1',
      () async {
        // Записываем напрямую в Hive (симулируем данные из предыдущей сессии)
        final hiveBox = Hive.box<dynamic>('listingsBox');
        const ttl = Duration(minutes: 5);
        await hiveBox.put('cold_key', {
          '_ts': DateTime.now().toIso8601String(),
          '_ttl': ttl.inMilliseconds,
          'data': 'from_hive',
        });

        // L1 пустой — промоция ещё не произошла
        expect(cache.l1Size, equals(0));

        // get должен найти данные в L2 и вернуть их
        final result = cache.get<String>('cold_key');
        expect(result, equals('from_hive'));

        // После чтения данные должны быть прокачаны в L1
        expect(cache.l1Size, equals(1));
      },
    );

    test(
      'L2→L1: истёкшая запись в Hive удаляется, get возвращает null',
      () async {
        final hiveBox = Hive.box<dynamic>('listingsBox');
        // Записываем с уже истёкшим временем
        await hiveBox.put('stale_key', {
          '_ts': DateTime.now()
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
          '_ttl': const Duration(
            minutes: 5,
          ).inMilliseconds, // TTL = 5 мин, но записано 10 мин назад
          'data': 'stale',
        });

        // get должен обнаружить, что TTL истёк
        expect(cache.get<String>('stale_key'), isNull);

        // Ключ должен быть удалён из L2
        expect(hiveBox.containsKey('stale_key'), isFalse);
      },
    );

    test('clearAll: удаляет персистентные данные из L2', () async {
      cache.set('persist_c', 'value', persist: true);
      await cache.clearAll();

      // L2 тоже должен быть очищен
      final hiveBox = Hive.box<dynamic>('listingsBox');
      expect(hiveBox.containsKey('persist_c'), isFalse);
      expect(cache.get<String>('persist_c'), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // invalidateByPrefix — L1 + L2
  // ══════════════════════════════════════════════════════════════════════════

  group('invalidateByPrefix', () {
    test('удаляет все ключи с указанным префиксом из L1', () async {
      cache.set('ns:alpha', 'v1');
      cache.set('ns:beta', 'v2');
      cache.set('other:gamma', 'v3');

      await cache.invalidateByPrefix('ns:');

      expect(cache.get<String>('ns:alpha'), isNull);
      expect(cache.get<String>('ns:beta'), isNull);
      // Ключ без префикса не затронут
      expect(cache.get<String>('other:gamma'), equals('v3'));
    });

    test('удаляет ключи с префиксом из L2 (persist)', () async {
      cache.set('cat:1', 'c1', persist: true);
      cache.set('cat:2', 'c2', persist: true);
      cache.set('adv:1', 'a1', persist: true);

      await cache.invalidateByPrefix('cat:');

      expect(cache.get<String>('cat:1'), isNull);
      expect(cache.get<String>('cat:2'), isNull);
      // Другой префикс не затронут
      expect(cache.get<String>('adv:1'), equals('a1'));

      // Проверяем Hive напрямую
      final hiveBox = Hive.box<dynamic>('listingsBox');
      expect(hiveBox.containsKey('cat:1'), isFalse);
      expect(hiveBox.containsKey('cat:2'), isFalse);
      expect(hiveBox.containsKey('adv:1'), isTrue);
    });

    test('не выбрасывает если нет ключей с данным префиксом', () async {
      cache.set('foo', 'bar');
      expect(() async => cache.invalidateByPrefix('unknown:'), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // clearAll
  // ══════════════════════════════════════════════════════════════════════════

  group('clearAll', () {
    test('очищает все записи L1', () async {
      cache.set('x', 1);
      cache.set('y', 2);
      cache.set('z', 3);
      expect(cache.l1Size, equals(3));

      await cache.clearAll();

      expect(cache.l1Size, equals(0));
    });

    test('после clearAll все get возвращают null', () async {
      cache.set('p', 'present');
      cache.set('q', 'queued', persist: true);

      await cache.clearAll();

      expect(cache.get<String>('p'), isNull);
      expect(cache.get<String>('q'), isNull);
    });

    test('после clearAll можно снова записывать данные', () async {
      cache.set('before', 'old');
      await cache.clearAll();

      cache.set('after', 'new');
      expect(cache.get<String>('after'), equals('new'));
    });
  });
}
