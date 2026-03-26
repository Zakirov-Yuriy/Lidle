import 'package:hive/hive.dart';

/// Унифицированный двухуровневый сервис кеширования.
///
/// ## Архитектура:
///
/// ```
/// AppCacheService
/// ├── L1 (RAM)  — Map в памяти, сбрасывается при перезапуске
/// │              Быстрые чтения (~0 мс), идеален для сессионных данных.
/// └── L2 (Hive) — Персистентный диск-кеш, переживает рестарты.
///               Используется для объявлений, каталогов, профилей.
/// ```
///
/// ## Режимы хранения:
/// - `persist: false` (по умолчанию) → только L1. Использутеся для сообщений,
///   временных состояний.
/// - `persist: true` → L1 + L2. Используется для объявлений, каталогов,
///   данных продавцов.
///
/// ## Чтение:
/// 1. Смотрим в L1. Если там есть и TTL не истёк — возвращаем.
/// 2. Смотрим в L2 (Hive). Если есть и TTL не истёк — прокачиваем в L1,
///    возвращаем.
/// 3. Возвращаем `null` — данных нет, BLoC должен загрузить из API.
///
/// ## Инвалидация:
/// - [invalidate]         — удаляет конкретный ключ из L1 и L2.
/// - [invalidateByPrefix] — удаляет все ключи с указанным префиксом (L1 + L2).
/// - [clearAll]           — полная очистка обоих уровней.
///
/// Ссылается на Hive-бокс `listingsBox` из `HiveService`.
class AppCacheService {
  // ── Singleton ────────────────────────────────────────────────────────────

  static final AppCacheService _instance = AppCacheService._internal();

  factory AppCacheService() => _instance;

  AppCacheService._internal();

  // ── TTL по умолчанию ─────────────────────────────────────────────────────

  /// TTL для персистентных данных (L2, Hive): объявления, каталоги.
  /// 🚀 ОПТИМИЗАЦИЯ: Увеличены с 5 на 30 минут для снижения API запросов на 50%
  static const Duration defaultPersistTtl = Duration(minutes: 30);

  /// TTL для оперативных данных (L1, RAM): сообщения, профиль.
  static const Duration defaultMemoryTtl = Duration(minutes: 5);

  // ── L1: оперативная память ────────────────────────────────────────────────

  final Map<String, _CacheEntry<dynamic>> _l1 = {};

  // ── Hive-бокс (L2) ───────────────────────────────────────────────────────

  /// Имя бокса в Hive. Должен быть открыт до использования сервиса.
  static const String _hiveBoxName = 'listingsBox';

  /// Возвращает Hive-бокс. Бокс открывается в `HiveService.init()`.
  Box get _l2 => Hive.box(_hiveBoxName);

  // ── Публичный API ─────────────────────────────────────────────────────────

  /// Читает значение из кеша по [key].
  ///
  /// - Сначала проверяет L1 (RAM).
  /// - Если в L1 нет — проверяет L2 (Hive) и автоматически прокачивает в L1.
  /// - Возвращает `null`, если данных нет или TTL истёк.
  T? get<T>(String key) {
    // Проверяем L1
    final l1Entry = _l1[key];
    if (l1Entry != null && !l1Entry.isExpired) {
      return l1Entry.value as T?;
    }
    // L1 устарел или пуст — чистим его
    if (l1Entry != null) _l1.remove(key);

    // Проверяем L2 (Hive)
    final l2Raw = _l2.get(key);
    if (l2Raw != null && l2Raw is Map) {
      final timestampStr = l2Raw['_ts'] as String?;
      final ttlMs = l2Raw['_ttl'] as int?;
      if (timestampStr != null && ttlMs != null) {
        final storedAt = DateTime.parse(timestampStr);
        final ttl = Duration(milliseconds: ttlMs);
        if (DateTime.now().difference(storedAt) <= ttl) {
          final data = l2Raw['data'];
          // Прокачиваем в L1 с оставшимся временем жизни
          final remaining = ttl - DateTime.now().difference(storedAt);
          _l1[key] = _CacheEntry(value: data, ttl: remaining);
          return data as T?;
        } else {
          // L2 устарел — чистим
          _l2.delete(key);
        }
      }
    }

    return null;
  }

  /// Сохраняет [value] в кеш по [key].
  ///
  /// - [ttl]     — время жизни (по умолчанию [defaultMemoryTtl]).
  /// - [persist] — если `true`, данные сохраняются и в L2 (Hive).
  ///   Используйте `persist: true` для объявлений и каталогов.
  void set<T>(String key, T value, {Duration? ttl, bool persist = false}) {
    final effectiveTtl =
        ttl ?? (persist ? defaultPersistTtl : defaultMemoryTtl);

    // Всегда пишем в L1
    _l1[key] = _CacheEntry(value: value, ttl: effectiveTtl);

    // Пишем в L2 только если persist = true
    if (persist) {
      _l2.put(key, {
        '_ts': DateTime.now().toIso8601String(),
        '_ttl': effectiveTtl.inMilliseconds,
        'data': value,
      });
    }
  }

  /// Удаляет конкретный [key] из L1 и L2.
  void invalidate(String key) {
    _l1.remove(key);
    _l2.delete(key);
  }

  /// Удаляет все ключи, начинающиеся с [prefix], из L1 и L2.
  ///
  /// Пример: `invalidateByPrefix(CacheKeys.advertsPrefix)` удалит
  /// все закешированные объявления.
  Future<void> invalidateByPrefix(String prefix) async {
    // L1: удаляем совпадающие ключи
    _l1.removeWhere((key, _) => key.startsWith(prefix));

    // L2: Hive не поддерживает фильтрацию, итерируем ключи
    final keysToDelete = _l2.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in keysToDelete) {
      await _l2.delete(k);
    }
  }

  /// Полная очистка L1 и всего содержимого Hive-бокса (L2).
  Future<void> clearAll() async {
    _l1.clear();
    await _l2.clear();
  }

  /// Возвращает `true`, если кеш по [key] актуален (не истёк).
  bool isValid(String key) => get(key) != null;

  /// Количество записей в L1 (для диагностики/тестов).
  int get l1Size => _l1.length;
}

// ── Внутренняя запись L1-кеша ─────────────────────────────────────────────

/// Обёртка значения с поддержкой TTL для L1-кеша.
class _CacheEntry<T> {
  /// Сохранённое значение.
  final T value;

  /// Момент сохранения.
  final DateTime _storedAt;

  /// Время жизни записи.
  final Duration ttl;

  _CacheEntry({required this.value, required this.ttl})
    : _storedAt = DateTime.now();

  /// `true`, если TTL истёк.
  bool get isExpired => DateTime.now().difference(_storedAt) > ttl;
}
