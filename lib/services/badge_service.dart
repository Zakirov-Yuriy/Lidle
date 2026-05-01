// ============================================================
// "Сервис: Управление бейджами на иконке приложения"
// ============================================================
//
// Отвечает за отображение количества новых сообщений на иконке приложения.
// Бейджи видны даже когда приложение закрыто (на главном экране).
// Использует встроенный API iOS и нативный код для Android.

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'dart:io';

class BadgeService {
  // ── Singleton ────────────────────────────────────────────────────────────

  static final BadgeService _instance = BadgeService._internal();

  static final _logger = Logger();

  // Method Channel для взаимодействия с нативным кодом
  static const _badgeChannel = MethodChannel('com.lidle.app/badge');

  // Текущее количество непрочитанных сообщений
  int _currentBadgeCount = 0;

  factory BadgeService() {
    return _instance;
  }

  BadgeService._internal();

  // ── Public API ───────────────────────────────────────────────────────────

  /// Инициализация сервиса
  Future<void> initialize() async {
    try {
      _logger.i('🔔 BadgeService инициализирован (платформа: ${Platform.operatingSystem})');
    } catch (e) {
      _logger.w('⚠️ Ошибка инициализации BadgeService: $e');
    }
  }

  /// Установить количество новых сообщений на иконке приложения
  /// [count] - количество непрочитанных сообщений (0 = очистить бейдж)
  ///
  /// **Пример использования**:
  /// ```dart
  /// await BadgeService().updateBadgeCount(5); // Показать 5 на иконке
  /// await BadgeService().clearBadge(); // Очистить бейдж
  /// ```
  Future<void> updateBadgeCount(int count) async {
    // Не обновляем если количество не изменилось
    if (_currentBadgeCount == count) {
      return;
    }

    try {
      await _badgeChannel.invokeMethod<void>(
        'setBadgeCount',
        {'count': count},
      );

      if (count > 0) {
        _logger.i('🔔 Бейдж обновлён: $count непрочитанных сообщений');
      } else {
        _logger.i('🔔 Бейдж очищен');
      }

      _currentBadgeCount = count;
    } catch (e) {
      // Ошибка при установке бейджа (платформа может не поддерживать)
      _logger.w('⚠️ Ошибка при обновлении бейджа: $e');
      // Продолжаем работу, просто без физического бейджа на иконке
      _currentBadgeCount = count;
    }
  }

  /// Очистить бейдж на иконке приложения
  /// Вызывается когда пользователь открывает чаты или просматривает сообщения
  Future<void> clearBadge() async {
    await updateBadgeCount(0);
  }

  /// Увеличить количество на бейджа на 1
  /// Используется когда приходит новое сообщение
  Future<void> incrementBadge() async {
    await updateBadgeCount(_currentBadgeCount + 1);
  }

  /// Получить текущее количество сообщений на бейджа
  int get currentBadgeCount => _currentBadgeCount;
}
