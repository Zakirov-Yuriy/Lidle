// ============================================================
// "Сервис: Получение информации об устройстве"
// ============================================================

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:lidle/core/logger.dart';

/// Модель информации об устройстве
class DeviceInfo {
  final String name; // Название устройства (например "iPhone 15" или "Redmi 14C")
  final String model; // Модель (например "iPhone15,2" или "Redmi 14C")
  final String manufacturer; // Производитель (Xiaomi, Samsung и т.д.)
  final String osVersion; // Версия ОС
  final String? buildVersion; // Версия сборки
  final String appVersion; // Версия приложения
  final String platform; // Платформа (iOS, Android, Web)

  DeviceInfo({
    required this.name,
    required this.model,
    this.manufacturer = '',
    required this.osVersion,
    this.buildVersion,
    required this.appVersion,
    required this.platform,
  });

  /// Получить полное название устройства
  String getFullName() {
    if (manufacturer.isEmpty) {
      return name;
    }
    return '$manufacturer $name';
  }
}

/// Сервис для получения информации об устройстве
class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static String? _cachedAppVersion;
  static DeviceInfo? _cachedDeviceInfo;

  /// Инициализировать сервис (вызвать один раз при запуске приложения)
  static Future<void> initialize() async {
    try {
      _cachedAppVersion = 'v1.4.1'; // Это будет переопределено в runtime
      // Получаем информацию об устройстве во время инициализации
      _cachedDeviceInfo = await getDeviceInfo();
    } catch (e) {
      // log.d('⚠️ Error initializing DeviceInfoService: $e');
    }
  }

  /// Получить версию приложения
  static String getAppVersion() {
    return _cachedAppVersion ?? 'v1.0.0';
  }

  /// Получить название платформы
  static String getPlatformName() {
    if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isLinux) {
      return 'Linux';
    } else {
      return 'Web';
    }
  }

  /// Получить информацию об устройстве
  static Future<DeviceInfo> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidDeviceInfo();
      } else if (Platform.isIOS) {
        return await _getIOSDeviceInfo();
      } else {
        return _getWebDeviceInfo();
      }
    } catch (e) {
      // log.d('❌ Error getting device info: $e');
      return DeviceInfo(
        name: 'Unknown Device',
        model: 'Unknown',
        manufacturer: 'Unknown',
        osVersion: 'Unknown',
        appVersion: 'v1.0.0',
        platform: getPlatformName(),
      );
    }
  }

  /// Получить информацию об Android устройстве
  static Future<DeviceInfo> _getAndroidDeviceInfo() async {
    try {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      
      // Получаем информацию о версии
      String osVersion = androidInfo.version.release ?? 'Unknown';
      String? buildVersion = androidInfo.version.securityPatch;

      return DeviceInfo(
        name: androidInfo.model,
        model: androidInfo.model,
        manufacturer: androidInfo.manufacturer,
        osVersion: osVersion,
        buildVersion: buildVersion,
        appVersion: getAppVersion(),
        platform: 'Android',
      );
    } catch (e) {
      // log.d('❌ Error getting Android device info: $e');
      return DeviceInfo(
        name: 'Android Device',
        model: 'Unknown',
        manufacturer: 'Unknown',
        osVersion: Platform.operatingSystemVersion,
        appVersion: getAppVersion(),
        platform: 'Android',
      );
    }
  }

  /// Получить информацию об iOS устройстве
  static Future<DeviceInfo> _getIOSDeviceInfo() async {
    try {
      final iosInfo = await _deviceInfoPlugin.iosInfo;

      return DeviceInfo(
        name: _getIOSDeviceName(iosInfo.model),
        model: iosInfo.model,
        manufacturer: 'Apple',
        osVersion: iosInfo.systemVersion,
        buildVersion: iosInfo.name,
        appVersion: getAppVersion(),
        platform: 'iOS',
      );
    } catch (e) {
      // log.d('❌ Error getting iOS device info: $e');
      return DeviceInfo(
        name: 'iPhone',
        model: 'Unknown',
        manufacturer: 'Apple',
        osVersion: Platform.operatingSystemVersion,
        appVersion: getAppVersion(),
        platform: 'iOS',
      );
    }
  }

  /// Получить информацию о Web устройстве
  static DeviceInfo _getWebDeviceInfo() {
    return DeviceInfo(
      name: 'Web Browser',
      model: 'Web',
      manufacturer: 'Web',
      osVersion: Platform.operatingSystemVersion,
      appVersion: getAppVersion(),
      platform: 'Web',
    );
  }

  /// Получить название iOS устройства по модели
  static String _getIOSDeviceName(String model) {
    // Маппинг идентификаторов iOS устройств на их названия
    final models = {
      'iPhone13,1': 'iPhone 12 mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      'iPhone14,2': 'iPhone 13',
      'iPhone14,3': 'iPhone 13 Pro',
      'iPhone14,4': 'iPhone 13 mini',
      'iPhone14,5': 'iPhone 13 Pro Max',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      'iPhone15,1': 'iPhone 14 Pro',
      'iPhone15,2': 'iPhone 14 Pro Max',
      'iPhone15,3': 'iPhone 15',
      'iPhone15,4': 'iPhone 15 Pro',
      'iPhone15,5': 'iPhone 15 Pro Max',
      'iPhone15,6': 'iPhone 15 Plus',
      'iPhone16,1': 'iPhone 16',
      'iPhone16,2': 'iPhone 16 Plus',
      'iPhone17,1': 'iPhone 16 Pro',
      'iPhone17,2': 'iPhone 16 Pro Max',
    };

    return models[model] ?? 'iPhone';
  }

  /// Получить кешированную информацию об устройстве (быстро)
  static DeviceInfo? getCachedDeviceInfo() {
    return _cachedDeviceInfo;
  }
}


