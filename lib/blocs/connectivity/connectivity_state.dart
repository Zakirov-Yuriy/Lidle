// ============================================================
// "Состояния подключения к интернету"
// ============================================================

abstract class ConnectivityState {
  const ConnectivityState();
}

/// Начальное состояние - соединение проверяется
class ConnectivityInitial extends ConnectivityState {
  const ConnectivityInitial();
}

/// Соединение активно
class ConnectedState extends ConnectivityState {
  const ConnectedState();
}

/// Нет соединения с интернетом
class DisconnectedState extends ConnectivityState {
  const DisconnectedState();
}
