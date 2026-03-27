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
