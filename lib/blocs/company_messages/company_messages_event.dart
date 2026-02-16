abstract class CompanyMessagesEvent {
  const CompanyMessagesEvent();
}

class LoadCompanyMessages extends CompanyMessagesEvent {
  /// Если true, всегда загружает данные заново (игнорирует кеш).
  /// Используется при pull-to-refresh.
  final bool forceRefresh;

  const LoadCompanyMessages({this.forceRefresh = false});
}

class ArchiveCompanyMessages extends CompanyMessagesEvent {
  final List<int> indices;

  const ArchiveCompanyMessages(this.indices);
}

class UnarchiveCompanyMessages extends CompanyMessagesEvent {
  final List<int> indices;

  const UnarchiveCompanyMessages(this.indices);
}
