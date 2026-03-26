/// Кеш для результатов getPriceOffers()
/// 
/// Предотвращает повторные запросы для одного и того же объявления
/// в течение определенного времени (TTL).
/// 
/// Использование:
/// ```dart
/// final cache = PriceOffersCache.instance;
/// 
/// // Получить из кеша или запустить запрос
/// final offers = await cache.getOffers(
///   advertId: 147,
///   advertSlug: 'adverts',
///   token: token,
///   onMiss: () => ApiService.getPriceOffers(...),
/// );
/// 
/// // Очистить кеш для одного объявления
/// cache.invalidate(advertId: 147);
/// 
/// // Очистить весь кеш
/// cache.clear();
/// ```

/// Ключ для хранения данных в кеше
class _CacheKey {
  final int advertId;
  final String advertSlug;
  
  _CacheKey({required this.advertId, required this.advertSlug});
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CacheKey && 
        advertId == other.advertId && 
        advertSlug == other.advertSlug;
  }
  
  @override
  int get hashCode => advertId.hashCode ^ advertSlug.hashCode;
  
  @override
  String toString() => '${advertId}_$advertSlug';
}

/// Информация о кешированном объекте
class _CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;
  
  _CacheEntry({
    required this.data,
    required this.ttl,
  }) : createdAt = DateTime.now();
  
  /// Проверить если кеш еще свежий
  bool get isValid => DateTime.now().difference(createdAt) < ttl;
}

/// Кеш для результатов getPriceOffers()
class PriceOffersCache {
  static final PriceOffersCache _instance = PriceOffersCache._internal();
  
  /// TTL (Time To Live) для кешированных данных
  /// По-умолчанию 5 минут
  static const Duration defaultTtl = Duration(minutes: 5);
  
  /// Внутренний кеш данных
  final Map<_CacheKey, _CacheEntry<List<Map<String, dynamic>>>> _cache = {};
  
  /// Кеш запросов которые сейчас выполняются (для дедупликации)
  final Map<_CacheKey, Future<List<Map<String, dynamic>>>> _pendingRequests = {};
  
  PriceOffersCache._internal();
  
  factory PriceOffersCache() {
    return _instance;
  }
  
  static PriceOffersCache get instance => _instance;
  
  /// Получить offers для объявления из кеша или запустить запрос
  /// 
  /// Параметры:
  /// - advertId: ID объявления
  /// - advertSlug: тип объявления (adverts, services и т.д.)
  /// - token: токен авторизации
  /// - onMiss: функция которая вызывается если нет в кеше
  /// - ttl: время жизни кеша (по-умолчанию 5 минут)
  Future<List<Map<String, dynamic>>> getOffers({
    required int advertId,
    required String advertSlug,
    required String token,
    required Future<List<Map<String, dynamic>>> Function() onMiss,
    Duration? ttl,
  }) async {
    final key = _CacheKey(advertId: advertId, advertSlug: advertSlug);
    ttl ??= defaultTtl;
    
    // Проверяем есть ли уже такой запрос в полете (дедупликация)
    if (_pendingRequests.containsKey(key)) {
      print('📦 PriceOffersCache: Дедупликация для advert_id=$advertId - ждем существующий запрос');
      return _pendingRequests[key]!;
    }
    
    // Проверяем есть ли в кеше и если он свежий
    if (_cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (entry.isValid) {
        print('💾 PriceOffersCache: Используем кеш для advert_id=$advertId (возраст ${DateTime.now().difference(entry.createdAt).inSeconds}s)');
        return entry.data;
      } else {
        print('⏰ PriceOffersCache: Кеш истек для advert_id=$advertId (возраст ${DateTime.now().difference(entry.createdAt).inMinutes}m)');
        _cache.remove(key);
      }
    }
    
    // Если нет в кеше, запускаем запрос
    print('🌐 PriceOffersCache: Запускаем запрос для advert_id=$advertId');
    final requestFuture = onMiss();
    _pendingRequests[key] = requestFuture;
    
    try {
      final result = await requestFuture;
      
      // Сохраняем в кеш
      _cache[key] = _CacheEntry(data: result, ttl: ttl);
      print('✅ PriceOffersCache: Закешировано ${result.length} offers для advert_id=$advertId (TTL=${ttl.inMinutes}m)');
      
      return result;
    } finally {
      // Удаляем из pending запросов
      _pendingRequests.remove(key);
    }
  }
  
  /// Очистить кеш для одного объявления
  void invalidate({required int advertId, String? advertSlug}) {
    if (advertSlug != null) {
      final key = _CacheKey(advertId: advertId, advertSlug: advertSlug);
      _cache.remove(key);
      print('🗑️ PriceOffersCache: Очищен кеш для advert_id=$advertId');
    } else {
      // Очистить все объявления с этим ID (все типы)
      final keysToRemove = _cache.keys
          .where((k) => k.advertId == advertId)
          .toList();
      
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
      print('🗑️ PriceOffersCache: Очищены ${keysToRemove.length} записей для advert_id=$advertId');
    }
  }
  
  /// Очистить весь кеш
  void clear() {
    final count = _cache.length;
    _cache.clear();
    print('🧹 PriceOffersCache: Очищен весь кеш ($count записей)');
  }
  
  /// Получить статистику кеша
  CacheStats get stats => CacheStats(
    totalEntries: _cache.length,
    validEntries: _cache.values.where((e) => e.isValid).length,
    expiredEntries: _cache.values.where((e) => !e.isValid).length,
    pendingRequests: _pendingRequests.length,
  );
  
  /// Получить информацию о содержимом кеша (для дебага)
  Map<String, dynamic> debugInfo() {
    return {
      'total': _cache.length,
      'valid': _cache.values.where((e) => e.isValid).length,
      'expired': _cache.values.where((e) => !e.isValid).length,
      'pending': _pendingRequests.length,
      'entries': _cache.entries
          .map((e) => {
            'key': e.key.toString(),
            'age_seconds': DateTime.now().difference(e.value.createdAt).inSeconds,
            'valid': e.value.isValid,
            'offers_count': e.value.data.length,
          })
          .toList(),
    };
  }
}

/// Статистика кеша
class CacheStats {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;
  final int pendingRequests;
  
  CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
    required this.pendingRequests,
  });
  
  @override
  String toString() => '📦 Cache: $validEntries/$totalEntries valid, $expiredEntries expired, $pendingRequests pending';
}
