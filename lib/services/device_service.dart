// ============================================================
// "Сервис: Управление устройствами пользователя"
// ============================================================

import 'api_service.dart';
import '../models/device_model.dart';

/// Сервис для работы с устройствами пользователя.
/// Предоставляет методы для получения списка устройств и удаления устройства.
class DeviceService {
  /// Получить список всех устройств текущего пользователя.
  ///
  /// Returns: [DevicesResponse] со списком устройств
  /// Throws: Exception если произошла ошибка API или сетевая ошибка
  static Future<DevicesResponse> getDevices({String? token}) async {
    try {
      final response = await ApiService.get(
        '/me/settings/devices',
        token: token,
      );
      return DevicesResponse.fromJson(response);
    } catch (e) {
      // Попытка обновить токен при истечении и повторить запрос
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return getDevices(token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Удалить устройство по ID.
  ///
  /// Parameters:
  /// - [deviceId]: ID устройства для удаления
  /// - [token]: JWT токен аутентификации (опционально)
  ///
  /// Returns: [DeviceDeleteResponse] с результатом удаления
  /// Throws: Exception если произошла ошибка API или сетевая ошибка
  static Future<DeviceDeleteResponse> removeDevice({
    required int deviceId,
    String? token,
  }) async {
    try {
      final response = await ApiService.delete(
        '/me/settings/devices/$deviceId',
        token: token,
      );
      return DeviceDeleteResponse.fromJson(response);
    } catch (e) {
      // Попытка обновить токен при истечении и повторить запрос
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return removeDevice(deviceId: deviceId, token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Удалить все другие устройства (завершить все другие сеансы).
  /// Note: Если API поддерживает этот endpoint, используйте его.
  /// Если нет - используйте removeDevice() в цикле для каждого устройства.
  static Future<void> removeAllOtherDevices({
    required List<int> deviceIds,
    String? token,
  }) async {
    try {
      for (final deviceId in deviceIds) {
        await removeDevice(deviceId: deviceId, token: token);
      }
    } catch (e) {
      rethrow;
    }
  }
}
