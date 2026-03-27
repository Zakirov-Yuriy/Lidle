// ============================================================
// "Фоновый сервис: Проверка новых сообщений в фоне"
// ============================================================
//
// Обработчик для workmanager, вызывается периодически
// даже когда приложение свернуто (в background).
// Проверяет новые сообщения и отправляет уведомления.

import 'package:logger/logger.dart';
import 'package:lidle/services/message_polling_service.dart';

final _logger = Logger();

/// Функция которая вызывается в background для проверки новых сообщений
/// Эта функция вызывается workmanager'ом каждые 15 минут
/// ВАЖНО: Вызывается ВНЕ контекста приложения (даже когда оно свернуто)
Future<bool> backgroundMessageCheck() async {
  try {
    _logger.i('🌙 [BACKGROUND TASK] Фоновая проверка сообщений запущена');

    // Инициализируем сервис полинга и выполняем одноразовую проверку
    final pollingService = MessagePollingService();
    
    // Используем публичный метод для одноразовой проверки
    // (загружает ID и проверяет новые сообщения)
    await pollingService.checkNewMessagesOnce();

    _logger.i('🌙 [BACKGROUND TASK] Фоновая проверка завершена успешно');
    return true;
  } catch (e) {
    _logger.e('🌙 [BACKGROUND TASK] Ошибка при фоновой проверке: $e');
    return false;
  }
}
