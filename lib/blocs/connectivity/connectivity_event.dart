// ============================================================
// "События изменения статуса подключения к интернету"
// ============================================================

abstract class ConnectivityEvent {
  const ConnectivityEvent();
}

/// Событие когда соединение восстановлено
class ConnectedEvent extends ConnectivityEvent {
  const ConnectedEvent();
}

/// Событие когда соединение потеряно
class DisconnectedEvent extends ConnectivityEvent {
  const DisconnectedEvent();
}

/// Событие для проверки текущего статуса сети
class CheckConnectivityEvent extends ConnectivityEvent {
  const CheckConnectivityEvent();
}

/// Событие для изменения предпочтения типа подключения
/// [preference] - предпочитаемый тип: 'wifi', 'mobile', 'any'
class SetNetworkPreferenceEvent extends ConnectivityEvent {
  final String preference; // 'wifi', 'mobile', 'any'
  
  const SetNetworkPreferenceEvent(this.preference);
}
