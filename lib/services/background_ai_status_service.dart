// ============================================================
// "Фоновый сервис: уведомление о завершении ИИ-обработки объявлений"
// ============================================================
//
// Обработчик для workmanager. Вызывается периодически даже когда приложение
// свёрнуто или закрыто (в background), из того же цикла, что и фоновая
// проверка сообщений (см. background_message_service.dart и main.dart).
//
// Опрашивает лёгкий эндпоинт
//   GET /me/adverts/moderation-ai-status  ->  { total, processed, all_done }
// и, как только обработка переходит из «идёт» в «всё готово» (all_done из
// false в true при total > 0), показывает ЛОКАЛЬНОЕ уведомление
// «ИИ завершил обработку — зайдите и опубликуйте объявления».
//
// В отличие от AiCompletionService (попап поверх открытого приложения),
// это уведомление приходит, даже когда приложение закрыто.
//
// ВАЖНО: выполняется ВНЕ контекста UI (в фоновом изоляте workmanager).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import 'package:lidle/hive_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/notification_service.dart';

final _logger = Logger();

/// Ключ в Hive для запоминания прошлого состояния all_done между запусками
/// фоновой задачи (изолят каждый раз новый, память не сохраняется).
const String _kAiAllDoneKey = 'ai_all_done_last_bg';

/// Стабильный id уведомления (чтобы не плодить дубликаты).
const int _kAiDoneNotificationId = 90011;

/// Одноразовая фоновая проверка статуса ИИ-обработки.
/// Возвращает true при успешном выполнении (для workmanager).
Future<bool> backgroundAiStatusCheck() async {
  try {
    // Гарантируем инициализацию Hive в этом изоляте (идемпотентно: если уже
    // инициализировано текущим циклом задачи — просто ловим исключение).
    try {
      if (kIsWeb) {
        await Hive.initFlutter();
      } else {
        final dir = await getApplicationDocumentsDirectory();
        await Hive.initFlutter(dir.path);
      }
      await HiveService.init();
    } catch (_) {
      // Уже инициализировано в этом изоляте — продолжаем.
    }

    // Инициализируем локальные уведомления (в фоновом изоляте нужно заново).
    await NotificationService().initialize();

    // Лёгкий запрос: токен ApiService берёт из хранилища сам. Без токена
    // (гость / истёкшая сессия) вернётся 401 → уйдём в catch, ничего не делаем.
    final resp = await ApiService.get('/me/adverts/moderation-ai-status');

    final int total = (resp['total'] as num?)?.toInt() ?? 0;
    final bool allDone = resp['all_done'] == true;

    final dynamic prev = HiveService.getUserData(_kAiAllDoneKey);
    final bool wasAllDone = prev is bool ? prev : true;

    // Нет объявлений на модерации — публиковать нечего. Держим флаг true,
    // чтобы при появлении новой партии и её завершении уведомление сработало.
    if (total == 0) {
      await HiveService.saveUserData(_kAiAllDoneKey, true);
      return true;
    }

    // Переход «идёт обработка» -> «всё готово»: уведомляем ОДИН раз.
    if (allDone && !wasAllDone) {
      await NotificationService().showNotification(
        id: _kAiDoneNotificationId,
        title: 'ИИ завершил обработку',
        body: 'Все объявления из фида обработаны. '
            'Зайдите и опубликуйте их.',
        payload: 'ai_moderation_done',
      );
      _logger.i('🤖 [BG] Уведомление о завершении ИИ показано (total=$total)');
    }

    await HiveService.saveUserData(_kAiAllDoneKey, allDone);
    return true;
  } catch (e) {
    _logger.e('🤖 [BG] Ошибка фоновой проверки статуса ИИ: $e');
    return false;
  }
}
