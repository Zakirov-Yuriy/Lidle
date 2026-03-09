// ============================================================
// "BLoC States: Состояния для управления устройствами"
// ============================================================

import '../../models/device_model.dart';

abstract class DevicesState {
  const DevicesState();
}

/// Начальное состояние (ещё не начинали загрузку)
class DevicesInitial extends DevicesState {
  const DevicesInitial();
}

/// Состояние загрузки данных
class DevicesLoading extends DevicesState {
  const DevicesLoading();
}

/// Состояние успешной загрузки
class DevicesLoaded extends DevicesState {
  final List<DeviceModel> devices;
  
  /// Текущее устройство (первое в списке)
  final DeviceModel? currentDevice;
  
  /// Все остальные активные сеансы
  final List<DeviceModel> activeSessions;

  const DevicesLoaded({
    required this.devices,
    this.currentDevice,
    this.activeSessions = const [],
  });

  /// Копирование с изменениями
  DevicesLoaded copyWith({
    List<DeviceModel>? devices,
    DeviceModel? currentDevice,
    List<DeviceModel>? activeSessions,
  }) {
    return DevicesLoaded(
      devices: devices ?? this.devices,
      currentDevice: currentDevice ?? this.currentDevice,
      activeSessions: activeSessions ?? this.activeSessions,
    );
  }
}

/// Состояние пусто (нет устройств)
class DevicesEmpty extends DevicesState {
  const DevicesEmpty();
}

/// Состояние ошибки загрузки
class DevicesError extends DevicesState {
  final String message;

  const DevicesError(this.message);
}

/// Состояние удаления устройства
class DeviceRemoving extends DevicesState {
  final int deviceId;

  const DeviceRemoving(this.deviceId);
}

/// Состояние успешного удаления
class DeviceRemoved extends DevicesState {
  final int deviceId;
  final String message;

  const DeviceRemoved({required this.deviceId, required this.message});
}

/// Состояние ошибки удаления
class DeviceRemoveError extends DevicesState {
  final int deviceId;
  final String message;

  const DeviceRemoveError({required this.deviceId, required this.message});
}

/// Состояние при удалении всех других сеансов
class RemovingAllOtherSessions extends DevicesState {
  const RemovingAllOtherSessions();
}

/// Состояние успешного удаления всех других сеансов
class AllOtherSessionsRemoved extends DevicesState {
  const AllOtherSessionsRemoved();
}

/// Состояние ошибки при удалении всех других сеансов
class RemoveAllOtherSessionsError extends DevicesState {
  final String message;

  const RemoveAllOtherSessionsError(this.message);
}
