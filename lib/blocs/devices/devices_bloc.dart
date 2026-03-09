// ============================================================
// "BLoC: Управление состоянием устройств пользователя"
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'devices_event.dart';
import 'devices_state.dart';
import '../../services/device_service.dart';
import '../../services/token_service.dart';
import '../../models/device_model.dart';
import '../../hive_service.dart';

/// BLoC для управления состоянием устройств пользователя.
/// Обрабатывает события загрузки, удаления устройств и управления сеансами.
class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  /// Конструктор DevicesBloc.
  /// Инициализирует BLoC с начальным состоянием DevicesInitial.
  DevicesBloc() : super(const DevicesInitial()) {
    // Регистрируем обработчики событий
    on<LoadDevicesEvent>(_onLoadDevices);
    on<RemoveDeviceEvent>(_onRemoveDevice);
    on<RemoveAllOtherDevicesEvent>(_onRemoveAllOtherDevices);
    on<RefreshDevicesListEvent>(_onRefreshDevicesList);
  }

  /// Обработчик события загрузки списка устройств
  Future<void> _onLoadDevices(
    LoadDevicesEvent event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      // Получаем токен из хранилища
      final token = TokenService.currentToken;

      if (token == null || token.isEmpty) {
        emit(const DevicesError('Токен не найден'));
        return;
      }

      // Если не требуется обновление, проверяем кеш
      if (!event.forceRefresh) {
        final cachedDevices = _loadDevicesFromCache();
        if (cachedDevices != null && cachedDevices.isNotEmpty) {
          // Разделяем по типу платформы
          final currentPlatform = _getCurrentPlatformType();
          DeviceModel? currentDevice;
          List<DeviceModel> activeSessions = [];
          
          for (var device in cachedDevices) {
            if (device.deviceType.toLowerCase() == currentPlatform) {
              currentDevice = device;
            } else {
              activeSessions.add(device);
            }
          }
          
          if (currentDevice == null && cachedDevices.isNotEmpty) {
            currentDevice = cachedDevices.first;
            activeSessions = cachedDevices.length > 1 ? cachedDevices.sublist(1) : [];
          }
          
          emit(DevicesLoaded(
            devices: cachedDevices,
            currentDevice: currentDevice,
            activeSessions: activeSessions,
          ));
          // Обновляем данные в фоне
          _fetchAndCacheDevices(token, emit);
          return;
        }
      }

      // Показываем индикатор загрузки
      emit(const DevicesLoading());

      // Получаем список устройств с API
      final response = await DeviceService.getDevices(token: token);

      if (!response.success) {
        emit(DevicesError(
          response.message ?? 'Ошибка при получении списка устройств',
        ));
        return;
      }

      if (response.data.isEmpty) {
        emit(const DevicesEmpty());
        return;
      }

      // Сохраняем устройства в Hive
      _saveDevicesToCache(response.data);

      // Разделяем текущее устройство и активные сеансы
      final devices = response.data;
      print('📱 API вернул ${devices.length} устройств:');
      for (var device in devices) {
        print('  - ${device.name} (${device.deviceType})');
      }
      
      // Определяем текущее устройство по типу (iOS, Android, Web)
      final currentPlatform = _getCurrentPlatformType();
      DeviceModel? currentDevice;
      List<DeviceModel> activeSessions = [];
      
      // Ищем устройство, которое соответствует текущей платформе
      for (var device in devices) {
        if (device.deviceType.toLowerCase() == currentPlatform) {
          currentDevice = device;
        } else {
          activeSessions.add(device);
        }
      }
      
      // Если устройство той же платформы не найдено, берем первое
      if (currentDevice == null && devices.isNotEmpty) {
        currentDevice = devices.first;
        activeSessions = devices.length > 1 ? devices.sublist(1) : [];
      }
      
      print('✅ Текущее устройство: ${currentDevice?.name}');
      print('📋 Активные сеансы: ${activeSessions.length}');

      // Излучаем состояние успешной загрузки
      emit(DevicesLoaded(
        devices: devices,
        currentDevice: currentDevice,
        activeSessions: activeSessions,
      ));
    } catch (e) {
      final errorMessage = _parseErrorMessage(e);
      emit(DevicesError('Ошибка загрузки устройств: $errorMessage'));
    }
  }

  /// Загрузить устройства из кеша Hive
  List<DeviceModel>? _loadDevicesFromCache() {
    try {
      final cachedData = HiveService.getUserData('devices_cache');
      if (cachedData is List) {
        return cachedData
            .whereType<Map<String, dynamic>>()
            .map((data) => DeviceModel.fromJson(data))
            .toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Сохранить устройства в кеш Hive
  void _saveDevicesToCache(List<DeviceModel> devices) {
    try {
      final devicesList =
          devices.map((device) => device.toJson()).toList();
      HiveService.saveUserData('devices_cache', devicesList);
    } catch (e) {
      // print('❌ Error saving devices to cache: $e');
    }
  }

  /// Загрузить устройства с API и обновить кеш внутри состояния загрузки
  Future<void> _fetchAndCacheDevices(
    String token,
    Emitter<DevicesState> emit,
  ) async {
    try {
      final response = await DeviceService.getDevices(token: token);

      if (response.success && response.data.isNotEmpty) {
        _saveDevicesToCache(response.data);
        
        // Определяем текущее устройство по типу платформы
        final currentPlatform = _getCurrentPlatformType();
        DeviceModel? currentDevice;
        List<DeviceModel> activeSessions = [];
        
        for (var device in response.data) {
          if (device.deviceType.toLowerCase() == currentPlatform) {
            currentDevice = device;
          } else {
            activeSessions.add(device);
          }
        }
        
        if (currentDevice == null && response.data.isNotEmpty) {
          currentDevice = response.data.first;
          activeSessions = response.data.length > 1 ? response.data.sublist(1) : [];
        }
        
        emit(DevicesLoaded(
          devices: response.data,
          currentDevice: currentDevice,
          activeSessions: activeSessions,
        ));
      }
    } catch (e) {
      // Игнорируем ошибки при фоновом обновлении
    }
  }

  /// Обработчик события удаления одного устройства
  Future<void> _onRemoveDevice(
    RemoveDeviceEvent event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      final token = TokenService.currentToken;

      if (token == null || token.isEmpty) {
        emit(const DevicesError('Токен не найден'));
        return;
      }

      // Показываем состояние удаления
      emit(DeviceRemoving(event.deviceId));

      // Удаляем устройство
      final response = await DeviceService.removeDevice(
        deviceId: event.deviceId,
        token: token,
      );

      if (response.success) {
        // Излучаем событие успешного удаления
        emit(DeviceRemoved(
          deviceId: event.deviceId,
          message: response.message ?? 'Устройство успешно удалено',
        ));

        // Автоматически обновляем список после успешного удаления
        add(const RefreshDevicesListEvent());
      } else {
        emit(DeviceRemoveError(
          deviceId: event.deviceId,
          message: response.message ?? 'Ошибка при удалении устройства',
        ));
      }
    } catch (e) {
      final errorMessage = _parseErrorMessage(e);
      emit(DeviceRemoveError(
        deviceId: event.deviceId,
        message: 'Ошибка удаления: $errorMessage',
      ));
    }
  }

  /// Обработчик события удаления всех других сеансов
  Future<void> _onRemoveAllOtherDevices(
    RemoveAllOtherDevicesEvent event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      final token = TokenService.currentToken;

      if (token == null || token.isEmpty) {
        emit(const DevicesError('Токен не найден'));
        return;
      }

      // Получаем текущее состояние, чтобы узнать какие устройства удалять
      if (state is! DevicesLoaded) {
        emit(const RemoveAllOtherSessionsError(
          'Не удалось загрузить список устройств',
        ));
        return;
      }

      final currentState = state as DevicesLoaded;
      final devicesToRemove = currentState.activeSessions;

      if (devicesToRemove.isEmpty) {
        emit(const AllOtherSessionsRemoved());
        return;
      }

      emit(const RemovingAllOtherSessions());

      // Удаляем все другие устройства
      try {
        await DeviceService.removeAllOtherDevices(
          deviceIds: devicesToRemove.map((d) => d.id).toList(),
          token: token,
        );

        // Показываем состояние успеха
        emit(const AllOtherSessionsRemoved());

        // Обновляем список устройств
        add(const RefreshDevicesListEvent());
      } catch (e) {
        final errorMessage = _parseErrorMessage(e);
        emit(RemoveAllOtherSessionsError(
          'Ошибка при удалении сеансов: $errorMessage',
        ));
      }
    } catch (e) {
      final errorMessage = _parseErrorMessage(e);
      emit(RemoveAllOtherSessionsError(
        'Непредвиденная ошибка: $errorMessage',
      ));
    }
  }

  /// Обработчик события обновления списка устройств
  Future<void> _onRefreshDevicesList(
    RefreshDevicesListEvent event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      // Получаем токен из хранилища
      final token = TokenService.currentToken;

      if (token == null || token.isEmpty) {
        emit(const DevicesError('Токен не найден'));
        return;
      }

      // Получаем список устройств с API (всегда свежие данные)
      final response = await DeviceService.getDevices(token: token);

      if (!response.success) {
        emit(DevicesError(
          response.message ?? 'Ошибка при получении списка устройств',
        ));
        return;
      }

      if (response.data.isEmpty) {
        emit(const DevicesEmpty());
        return;
      }

      // Сохраняем в кеш
      _saveDevicesToCache(response.data);

      // Разделяем текущее устройство и активные сеансы по типу платформы
      final devices = response.data;
      final currentPlatform = _getCurrentPlatformType();
      DeviceModel? currentDevice;
      List<DeviceModel> activeSessions = [];
      
      for (var device in devices) {
        if (device.deviceType.toLowerCase() == currentPlatform) {
          currentDevice = device;
        } else {
          activeSessions.add(device);
        }
      }
      
      if (currentDevice == null && devices.isNotEmpty) {
        currentDevice = devices.first;
        activeSessions = devices.length > 1 ? devices.sublist(1) : [];
      }

      // Излучаем состояние успешной загрузки
      emit(DevicesLoaded(
        devices: devices,
        currentDevice: currentDevice,
        activeSessions: activeSessions,
      ));
    } catch (e) {
      final errorMessage = _parseErrorMessage(e);
      emit(DevicesError('Ошибка при обновлении списка: $errorMessage'));
    }
  }

  /// Получить тип платформы текущего устройства
  String _getCurrentPlatformType() {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isLinux) {
      return 'linux';
    }
    return 'web'; // Default to web if not recognized
  }

  /// Вспомогательный метод для парсинга сообщений об ошибках
  String _parseErrorMessage(dynamic error) {
    if (error is Exception) {
      final message = error.toString();
      // Удаляем префикс "Exception: " если он есть
      if (message.startsWith('Exception: ')) {
        return message.substring(10);
      }
      return message;
    }
    return error.toString();
  }
}
