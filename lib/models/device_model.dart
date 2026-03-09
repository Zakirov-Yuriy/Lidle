// ============================================================
// "Модель: Устройство пользователя"
// ============================================================

/// Модель одного устройства
class DeviceModel {
  final int id;
  final String name;
  final String deviceType;
  final String appVersion;
  final String? country;
  final DateTime lastUsedAt;
  final DateTime createdAt;

  DeviceModel({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.appVersion,
    this.country,
    required this.lastUsedAt,
    required this.createdAt,
  });

  /// Создание модели из JSON
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Device',
      deviceType: json['device_type'] as String? ?? 'unknown',
      appVersion: json['app_version'] as String? ?? 'v0.0.0',
      country: json['country'] as String?,
      lastUsedAt: json['last_used_at'] != null
          ? _parseDateTime(json['last_used_at'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? _parseDateTime(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'device_type': deviceType,
      'app_version': appVersion,
      'country': country,
      'last_used_at': lastUsedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Копирование с изменениями
  DeviceModel copyWith({
    int? id,
    String? name,
    String? deviceType,
    String? appVersion,
    String? country,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      appVersion: appVersion ?? this.appVersion,
      country: country ?? this.country,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Вспомогательный метод для парсинга даты в разных форматах
  static DateTime _parseDateTime(String dateStr) {
    try {
      // Формат от API: "01.03.2026 16:18"
      if (dateStr.contains(' ')) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('.');
        final timeParts = parts[1].split(':');
        return DateTime(
          int.parse(dateParts[2]), // год
          int.parse(dateParts[1]), // месяц
          int.parse(dateParts[0]), // день
          int.parse(timeParts[0]), // часы
          int.parse(timeParts[1]), // минуты
        );
      }
      // Стандартный ISO 8601 формат
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }
}

/// Модель ответа со списком устройств
class DevicesResponse {
  final bool success;
  final List<DeviceModel> data;
  final String? message;

  DevicesResponse({
    required this.success,
    required this.data,
    this.message,
  });

  /// Создание из JSON
  factory DevicesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> dataList = json['data'] as List<dynamic>? ?? [];
    return DevicesResponse(
      success: json['success'] as bool? ?? false,
      data: dataList
          .map((item) => DeviceModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String?,
    );
  }
}

/// Модель ответа при удалении устройства
class DeviceDeleteResponse {
  final bool success;
  final String? message;

  DeviceDeleteResponse({
    required this.success,
    this.message,
  });

  factory DeviceDeleteResponse.fromJson(Map<String, dynamic> json) {
    return DeviceDeleteResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}
