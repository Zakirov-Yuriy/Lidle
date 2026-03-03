// ============================================================
// "Сервис: Локальное хранилище сообщений и архива"
// ============================================================
//
// Фасад над HiveService для работы с локальными данными сообщений.
// Изолирует UI/BLoC от прямой зависимости от HiveService.

import 'package:lidle/hive_service.dart';

/// Сервис дла управления локально сохранёнными сообщениями и архивом.
///
/// Все методы делегируют вызовы в [HiveService], обеспечивая
/// единую точку доступа и упрощая последующее тестирование/замену.
class MessagesLocalService {
  MessagesLocalService._();

  // ─── Текущие сообщения ───────────────────────────────────

  /// Сохраняет текущий список сообщений в локальное хранилище.
  static Future<void> saveCurrentMessages(
    List<Map<String, dynamic>> messages,
  ) => HiveService.saveCurrentMessages(messages);

  /// Возвращает текущий список сохранённых сообщений.
  static List<Map<String, dynamic>> getCurrentMessages() =>
      HiveService.getCurrentMessages();

  // ─── Архив сообщений ─────────────────────────────────────

  /// Возвращает список архивированных сообщений.
  static List<Map<String, dynamic>> getArchivedMessages() =>
      HiveService.getArchivedMessages();

  /// Добавляет сообщение [message] в архив.
  static Future<void> addToArchive(Map<String, dynamic> message) =>
      HiveService.addToArchive(message);

  /// Восстанавливает сообщение из архива по индексу [archiveIndex].
  static Future<void> restoreFromArchive(int archiveIndex) =>
      HiveService.restoreFromArchive(archiveIndex);
}
