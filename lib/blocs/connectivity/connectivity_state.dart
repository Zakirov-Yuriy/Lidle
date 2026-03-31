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

/// Соединение активно (соответствует предпочтениям пользователя)
/// [availableTypes] - доступные типы подключения: wifi, mobile
/// [preferredType] - предпочтение пользователя: 'wifi', 'mobile', 'any'
class ConnectedState extends ConnectivityState {
  final List<String> availableTypes; // ['wifi'], ['mobile'], или ['wifi', 'mobile']
  final String preferredType; // 'wifi', 'mobile', 'any'

  const ConnectedState({
    this.availableTypes = const ['wifi', 'mobile'],
    this.preferredType = 'any',
  });

  /// Проверяет, соответствует ли текущее соединение предпочтению пользователя
  bool isConnectionAllowed() {
    if (preferredType == 'any') return true;
    return availableTypes.contains(preferredType);
  }
}

/// Нет соединения с интернетом или соединение не соответствует предпочтениям
/// [reason] - причина: 'no_internet' или 'preference_not_met'
/// [preferredType] - предпочтение пользователя
class DisconnectedState extends ConnectivityState {
  final String reason; // 'no_internet' или 'preference_not_met'
  final String preferredType; // 'wifi', 'mobile', 'any'
  final List<String> availableTypes; // Какие типы доступны

  const DisconnectedState({
    this.reason = 'no_internet',
    this.preferredType = 'any',
    this.availableTypes = const [],
  });
}
