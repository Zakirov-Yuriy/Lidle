abstract class MessagesEvent {
  const MessagesEvent();
}

class LoadMessages extends MessagesEvent {
  /// Если true, всегда загружает данные заново (игнорирует кеш).
  /// Используется при pull-to-refresh.
  final bool forceRefresh;

  const LoadMessages({this.forceRefresh = false});
}

class ArchiveMessages extends MessagesEvent {
  final List<int> indices;

  const ArchiveMessages(this.indices);
}

class UnarchiveMessages extends MessagesEvent {
  final List<int> indices;

  const UnarchiveMessages(this.indices);
}

/// Event для обновления списка сообщений при получении новых сообщений
/// Используется MessagePollingService при обнаружении новых сообщений
class RefreshMessages extends MessagesEvent {
  const RefreshMessages();
}

/// 🔴 Event для обновления количества непрочитанных сообщений в чате
class UpdateMessageUnreadCount extends MessagesEvent {
  final String senderName; // Имя отправителя для поиска в mainMessages
  final int unreadCount; // Новое количество непрочитанных (обычно 0)

  const UpdateMessageUnreadCount({
    required this.senderName,
    required this.unreadCount,
  });
}

/// 🔵 Event для синхронизации реальных Message данных в mainMessages
/// Вызывается после загрузки сообщений в messages_page.dart
class SyncMainMessages extends MessagesEvent {
  final List<Map<String, dynamic>> realMessages; // Реальные данные с API

  const SyncMainMessages({required this.realMessages});
}
