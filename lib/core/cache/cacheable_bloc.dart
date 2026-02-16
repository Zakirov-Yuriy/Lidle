import 'package:flutter_bloc/flutter_bloc.dart';

/// Карта для кеширования состояний BLoC'ов
/// Ключ: идентификатор кеша (например, 'profile_user_id_123')
/// Значение: объект состояния
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Duration> _cacheTTLs = {};

  static const Duration _defaultTTL = Duration(minutes: 5);

  factory CacheManager() {
    return _instance;
  }

  CacheManager._internal();

  /// Получить значение из кеша
  T? get<T>(String key) {
    if (_cache.containsKey(key)) {
      // Проверяем TTL
      final timestamp = _cacheTimestamps[key];
      final ttl = _cacheTTLs[key] ?? _defaultTTL;
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp);
        if (age > ttl) {
          // Кеш устарел, удаляем
          _cache.remove(key);
          _cacheTimestamps.remove(key);
          _cacheTTLs.remove(key);
          return null;
        }
      }
      return _cache[key] as T?;
    }
    return null;
  }

  /// Сохранить значение в кеш
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
    _cacheTTLs[key] = ttl ?? _defaultTTL;
  }

  /// Очистить кеш по ключу
  void clear(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    _cacheTTLs.remove(key);
  }

  /// Очистить весь кеш
  void clearAll() {
    _cache.clear();
    _cacheTimestamps.clear();
    _cacheTTLs.clear();
  }

  /// Проверить наличие значения в кеше
  bool contains(String key) {
    return get(key) != null;
  }
}
