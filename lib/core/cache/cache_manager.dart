import 'package:lidle/core/cache/cache_service.dart';

/// Устаревший адаптер-обёртка. Делегирует всё в [AppCacheService].
///
/// > **Deprecated**: Используйте [AppCacheService] напрямую.
/// > Этот класс оставлен для обратной совместимости до полного
/// > рефакторинга всех мест использования.
@Deprecated('Use AppCacheService instead')
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();

  factory CacheManager() => _instance;

  CacheManager._internal();

  // Делегируем в унифицированный сервис
  final _service = AppCacheService();

  /// Получить значение из кеша (L1 → L2).
  T? get<T>(String key) => _service.get<T>(key);

  /// Сохранить значение в кеш (только L1, без persist).
  void set<T>(String key, T value, {Duration? ttl}) =>
      _service.set<T>(key, value, ttl: ttl, persist: false);

  /// Очистить кеш по ключу (L1 + L2).
  void clear(String key) => _service.invalidate(key);

  /// Очистить весь кеш.
  Future<void> clearAll() => _service.clearAll();

  /// Проверить наличие актуального значения в кеше.
  bool contains(String key) => _service.isValid(key);
}
