/// Сервис для управления очередью API запросов
/// 
/// Решает проблему избыточного количества параллельных запросов.
/// Вместо Future.wait() который запускает все запросы одновременно,
/// используем очередь которая ограничивает количество одновременных запросов.
/// 
/// Пример:
/// ```
/// // Вместо:
/// final results = await Future.wait([req1(), req2(), req3()]);
/// 
/// // Используем:
/// final results = await ApiRequestQueue.instance.queueBatch([req1, req2, req3]);
/// ```

import 'dart:async';
import 'dart:collection';

/// Точка входа для управления очередью API запросов
class ApiRequestQueue {
  static final ApiRequestQueue _instance = ApiRequestQueue._internal();
  
  /// Максимальное количество одновременных запросов
  /// Рекомендуемое значение: 2-3 для мобильных приложений
  static const int maxConcurrentRequests = 3;
  
  /// Очередь ожидающих запросов
  final Queue<_QueuedRequest> _queue = Queue();
  
  /// Текущее количество выполняющихся запросов
  int _activeRequests = 0;
  
  /// Lock для потокобезопасности при работе с очередью
  final _queueLock = _AsyncLock();
  
  ApiRequestQueue._internal();
  
  /// Get singleton instance
  factory ApiRequestQueue() {
    return _instance;
  }
  
  /// Singleton getter для удобства
  static ApiRequestQueue get instance => _instance;
  
  /// Добавить одиночный запрос в очередь
  /// 
  /// ```dart
  /// final result = await ApiRequestQueue.instance.queue(() async {
  ///   return await someApiCall();
  /// });
  /// ```
  Future<T> queue<T>(Future<T> Function() request) async {
    final completer = Completer<T>();
    
    await _queueLock.acquire();
    try {
      _queue.add(_QueuedRequest<T>(
        request: request,
        completer: completer,
      ));
      _processQueue();
    } finally {
      _queueLock.release();
    }
    
    return completer.future;
  }
  
  /// Добавить группу запросов в очередь и выполнить их последовательно в группах
  /// 
  /// Параметры:
  /// - requests: список функций которые возвращают Future
  /// - batchSize: количество запросов в одной группе (по-умолчанию = maxConcurrentRequests)
  /// 
  /// Пример:
  /// ```dart
  /// // Запустит 6 запросов в двух группах по 3
  /// final results = await ApiRequestQueue.instance.queueBatch(
  ///   [req1, req2, req3, req4, req5, req6],
  ///   batchSize: 3,
  /// );
  /// ```
  Future<List<T>> queueBatch<T>(
    List<Future<T> Function()> requests, {
    int? batchSize,
  }) async {
    batchSize ??= maxConcurrentRequests;
    final results = <T>[];
    
    // Обрабатываем запросы группами
    for (int i = 0; i < requests.length; i += batchSize) {
      final batch = requests.sublist(
        i,
        (i + batchSize).clamp(0, requests.length),
      );
      
      // Запускаем все запросы в группе параллельно
      // (но они все равно будут соответствовать maxConcurrentRequests лимиту)
      final batchResults = await Future.wait(
        batch.map((req) => queue(req)),
      );
      
      results.addAll(batchResults);
    }
    
    return results;
  }
  
  /// Обработать очередь запросов
  void _processQueue() {
    while (_activeRequests < maxConcurrentRequests && _queue.isNotEmpty) {
      final queuedRequest = _queue.removeFirst();
      _activeRequests++;
      
      // Выполняем запрос в фоне и не ждем его
      _executeRequest(queuedRequest);
    }
  }
  
  /// Выполнить один запрос из очереди
  Future<void> _executeRequest<T>(_QueuedRequest<T> request) async {
    try {
      final result = await request.request();
      request.completer.complete(result);
    } catch (e) {
      request.completer.completeError(e);
    } finally {
      _activeRequests--;
      
      // После завершения, проверяем есть ли еще запросы в очереди
      _queueLock.acquire().then((_) {
        try {
          _processQueue();
        } finally {
          _queueLock.release();
        }
      });
    }
  }
  
  /// Получить текущее состояние очереди (для логирования/дебага)
  QueueStats get stats => QueueStats(
    activeRequests: _activeRequests,
    queuedRequests: _queue.length,
    maxConcurrent: maxConcurrentRequests,
  );
}

/// Информация о состоянии очереди
class QueueStats {
  final int activeRequests;
  final int queuedRequests;
  final int maxConcurrent;
  
  QueueStats({
    required this.activeRequests,
    required this.queuedRequests,
    required this.maxConcurrent,
  });
  
  @override
  String toString() => '📊 Queue: $activeRequests active, $queuedRequests pending, max=$maxConcurrent';
}

/// Внутренний класс для ранения информации о запросе в очереди
class _QueuedRequest<T> {
  final Future<T> Function() request;
  final Completer<T> completer;
  
  _QueuedRequest({
    required this.request,
    required this.completer,
  });
}

/// Простой async lock для потокобезопасить
class _AsyncLock {
  bool _locked = false;
  final Queue<Completer<void>> _waiters = Queue();
  
  Future<void> acquire() async {
    if (!_locked) {
      _locked = true;
      return;
    }
    
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }
  
  void release() {
    if (_waiters.isNotEmpty) {
      final completer = _waiters.removeFirst();
      completer.complete();
    } else {
      _locked = false;
    }
  }
}
