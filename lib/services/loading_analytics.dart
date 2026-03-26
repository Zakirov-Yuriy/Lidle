import 'package:lidle/services/loading_timer_service.dart';
import 'package:logger/logger.dart';

/// Утилита для анализа и логирования времени загрузки.
/// Используется для отладки производительности приложения.
class LoadingAnalytics {
  static final LoadingAnalytics _instance = LoadingAnalytics._internal();
  final Logger _logger = Logger();
  
  // Отслеживаем общее время для различных операций
  final Map<String, List<LoadingTimerResult>> _operationResults = {};

  LoadingAnalytics._internal();

  factory LoadingAnalytics() {
    return _instance;
  }

  /// Сохранить результат таймера для анализа
  void recordResult(LoadingTimerResult result) {
    if (!_operationResults.containsKey(result.operationKey)) {
      _operationResults[result.operationKey] = [];
    }
    _operationResults[result.operationKey]!.add(result);
  }

  /// Получить среднее время загрузки для операции
  double? getAverageTime(String operationKey) {
    final results = _operationResults[operationKey];
    if (results == null || results.isEmpty) return null;
    
    final totalMs = results.fold(0.0, (sum, r) => sum + r.totalDurationMs);
    return totalMs / results.length;
  }

  /// Получить минимальное время загрузки
  int? getMinTime(String operationKey) {
    final results = _operationResults[operationKey];
    if (results == null || results.isEmpty) return null;
    return results.map((r) => r.totalDurationMs).reduce((a, b) => a < b ? a : b);
  }

  /// Получить максимальное время загрузки
  int? getMaxTime(String operationKey) {
    final results = _operationResults[operationKey];
    if (results == null || results.isEmpty) return null;
    return results.map((r) => r.totalDurationMs).reduce((a, b) => a > b ? a : b);
  }

  /// Напечатать статистику по операции
  void printStatistics(String operationKey) {
    final results = _operationResults[operationKey];
    if (results == null || results.isEmpty) {
      _logger.w('📊 Нет данных для операции: $operationKey');
      return;
    }

    final avgTime = getAverageTime(operationKey)!;
    final minTime = getMinTime(operationKey)!;
    final maxTime = getMaxTime(operationKey)!;

    _logger.i(
'''
╔══════════════════════════════════════════════════════╗
║         📊 СТАТИСТИКА ВРЕМЕНИ ЗАГРУЗКИ               ║
╠══════════════════════════════════════════════════════╣
║ Операция:      $operationKey
║ Запросов:      ${results.length}
║ Среднее:       ${avgTime.toStringAsFixed(1)}ms
║ Мин:           ${minTime}ms
║ Макс:          ${maxTime}ms
║ Дельта:        ${maxTime - minTime}ms
╚══════════════════════════════════════════════════════╝
''',
    );
  }

  /// Очистить все записанные результаты
  void clearResults() {
    _operationResults.clear();
  }

  /// Получить все операции и их количество запросов
  Map<String, int> getOperationsSummary() {
    return _operationResults.map(
      (key, values) => MapEntry(key, values.length),
    );
  }

  /// Напечатать общую статистику всех операций
  void printAllStatistics() {
    if (_operationResults.isEmpty) {
      _logger.w('📊 Нет зафиксированных операций');
      return;
    }

    _logger.i(
'''
╔══════════════════════════════════════════════════════╗
║      📊 ОБЩАЯ СТАТИСТИКА ВЫЕ ОПЕРАЦИЙ               ║
╠══════════════════════════════════════════════════════╣
''');

    _operationResults.forEach((operation, results) {
      final avgTime = results.fold(0, (sum, r) => sum + r.totalDurationMs) / results.length;
      _logger.i('  $operation: ${results.length}x (avg: ${avgTime.toStringAsFixed(1)}ms)');
    });

    _logger.i('╚══════════════════════════════════════════════════════╝');
  }
}

/// Расширение для LoadingTimerResult для удобного логирования
extension LoadingTimerResultExt on LoadingTimerResult {
  /// Красиво напечатать результат с деталями
  void printDetails() {
    final Logger logger = Logger();
    logger.i(
'''
╔════════════════════════════════════════════════════╗
║          📊 ДЕТАЛИ ВРЕМЕНИ ЗАГРУЗКИ               ║
╠════════════════════════════════════════════════════╣
║ ⏱️  Операция:      $operationKey
║ 🦴 Скелет:       ${skeletonDurationMs}ms
║ ✅ Всего:        ${totalDurationMs}ms
║ 📈 После скел:   ${totalDurationMs - skeletonDurationMs}ms
║ 📊 % скелета:    ${((skeletonDurationMs / totalDurationMs) * 100).toStringAsFixed(1)}%
╚════════════════════════════════════════════════════╝
''',
    );

    // Сохраняем в глобальную статистику
    LoadingAnalytics().recordResult(this);
  }
}
