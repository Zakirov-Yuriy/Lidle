// ============================================================
// "BLoC Events: События для управления устройствами"
// ============================================================

abstract class DevicesEvent {
  const DevicesEvent();
}

/// Событие загрузки списка всех устройств пользователя
class LoadDevicesEvent extends DevicesEvent {
  /// Если true - игнорируем кеш и загружаем свежие данные
  final bool forceRefresh;

  const LoadDevicesEvent({this.forceRefresh = false});
}

/// Событие удаления одного устройства
class RemoveDeviceEvent extends DevicesEvent {
  final int deviceId;

  const RemoveDeviceEvent(this.deviceId);
}

/// Событие удаления всех других устройств (завершение всех сеансов)
class RemoveAllOtherDevicesEvent extends DevicesEvent {
  const RemoveAllOtherDevicesEvent();
}

/// Событие обновления списка устройств после удаления
class RefreshDevicesListEvent extends DevicesEvent {
  const RefreshDevicesListEvent();
}
