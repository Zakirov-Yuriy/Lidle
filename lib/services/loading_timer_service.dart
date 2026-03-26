import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Сервис для измерения времени загрузки контента и скелетов.
/// Отслеживает время от начала загрузки до полной готовности контента.
class LoadingTimerService {
  static final LoadingTimerService _instance = LoadingTimerService._internal();
  
  final Logger _logger = Logger();
  
  // Словарь для хранения времени начала загрузки по ключу операции
  final Map<String, DateTime> _loadingStartTimes = {};
  
  // Словарь для сохранения времени загрузки скелетов (когда начали показывать скелет)
  final Map<String, DateTime?> _skeletonStartTimes = {};

  LoadingTimerService._internal();

  factory LoadingTimerService() {
    return _instance;
  }

  /// Запустить таймер для операции загрузки
  /// [operationKey] - уникальный ключ операции (например, 'listings_load', 'profile_load')
  void startLoadingTimer(String operationKey) {
    _loadingStartTimes[operationKey] = DateTime.now();
    _skeletonStartTimes[operationKey] = DateTime.now();
    
    if (kDebugMode) {
      _logger.i('⏱️  Таймер загрузки запущен: [$operationKey]');
    }
  }

  /// Зафиксировать время завершения загрузки и вернуть результат
  /// [operationKey] - ключ операции
  /// [label] - описание операции для логирования
  LoadingTimerResult stopLoadingTimer(
    String operationKey, {
    String? label,
  }) {
    final startTime = _loadingStartTimes[operationKey];
    final skeletonStartTime = _skeletonStartTimes[operationKey];

    if (startTime == null) {
      if (kDebugMode) {
        _logger.w('⚠️  Таймер для операции [$operationKey] не был запущен');
      }
      return LoadingTimerResult(
        operationKey: operationKey,
        totalDurationMs: 0,
        skeletonDurationMs: 0,
      );
    }

    final now = DateTime.now();
    final totalDuration = now.difference(startTime);
    final skeletonDuration = skeletonStartTime != null
        ? now.difference(skeletonStartTime)
        : totalDuration;

    final result = LoadingTimerResult(
      operationKey: operationKey,
      totalDurationMs: totalDuration.inMilliseconds,
      skeletonDurationMs: skeletonDuration.inMilliseconds,
    );

    _logTimerResult(result, label);

    // Очистить таймеры
    _loadingStartTimes.remove(operationKey);
    _skeletonStartTimes.remove(operationKey);

    return result;
  }

  /// Получить текущее время прохождения тайма (не сбрасывая его)
  Duration? getCurrentDuration(String operationKey) {
    final startTime = _loadingStartTimes[operationKey];
    if (startTime == null) return null;
    return DateTime.now().difference(startTime);
  }

  /// Сбросить таймер без логирования результата
  void resetTimer(String operationKey) {
    _loadingStartTimes.remove(operationKey);
    _skeletonStartTimes.remove(operationKey);
  }

  /// Закрыть все активные таймеры
  void closeAll() {
    _loadingStartTimes.clear();
    _skeletonStartTimes.clear();
  }

  /// Приватный метод для логирования результатов
  void _logTimerResult(LoadingTimerResult result, String? customLabel) {
    final label = customLabel ?? result.operationKey;
    
    if (kDebugMode) {
      _logger.i(
        '''
╔════════════════════════════════════════════════════╗
║          📊 РЕЗУЛЬТАТЫ ИЗМЕРЕНИЯ ВРЕМЕНИ ЗАГРУЗКИ   ║
╠════════════════════════════════════════════════════╣
║ Операция:      $label
║ 🦴 Скелет:     ${result.skeletonDurationMs}ms
║ ✅ Всего:       ${result.totalDurationMs}ms
║ 📈 Прирост:    ${result.totalDurationMs - result.skeletonDurationMs}ms
╚════════════════════════════════════════════════════╝
''',
      );
    }
  }
}

/// Результат измерения времени загрузки
class LoadingTimerResult {
  /// Ключ операции
  final String operationKey;
  
  /// Общее время загрузки в миллисекундах
  final int totalDurationMs;
  
  /// Время отображения скелетной загрузки в миллисекундах
  final int skeletonDurationMs;

  LoadingTimerResult({
    required this.operationKey,
    required this.totalDurationMs,
    required this.skeletonDurationMs,
  });

  /// Красивый вывод результата
  @override
  String toString() => '''
LoadingTimerResult(
  operation: $operationKey,
  skeleton: ${skeletonDurationMs}ms,
  total: ${totalDurationMs}ms,
  afterSkeleton: ${totalDurationMs - skeletonDurationMs}ms
)''';
  
  /// Проверить если загрузка медленная
  bool isSlowLoading([int thresholdMs = 3000]) {
    return totalDurationMs > thresholdMs;
  }

  /// Проверить если скелет показывается долго
  bool isSlowSkeleton([int thresholdMs = 1500]) {
    return skeletonDurationMs > thresholdMs;
  }
}
