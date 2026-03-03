// ============================================================
// "Сервис: Управление жизненным циклом токена"
//
// Отвечает за:
// 1. Проактивное обновление токена (за 5 минут до истечения)
// 2. Декодирование JWT для получения времени истечения
// 3. Уведомление AuthBloc об истечении / обновлении токена
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../hive_service.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import 'api_service.dart';

/// Сервис управления жизненным циклом JWT-токена.
///
/// Принцип работы:
/// - При старте читает токен из Hive и декодирует время истечения (exp)
/// - Запускает таймер, который срабатывает за [_refreshBeforeExpireSeconds] до истечения
/// - При срабатывании таймера вызывает POST /auth/refresh-token
/// - Если refresh успешен — сохраняет новый токен и перезапускает таймер
/// - Если refresh не удался — отправляет TokenExpiredEvent в AuthBloc
class TokenService {
  /// За сколько секунд до истечения токена делать refresh (5 минут)
  static const int _refreshBeforeExpireSeconds = 5 * 60;

  /// Минимальное время жизни токена для запуска таймера (30 секунд)
  static const int _minTokenLifetimeSeconds = 30;

  /// Минимальный интервал между попытками refresh (в секундах) - защита от loop
  static const int _minRefreshIntervalSeconds = 2;

  Timer? _refreshTimer;
  BuildContext? _context;
  DateTime? _lastRefreshAttempt;

  // Singleton
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  /// Инициализирует сервис и запускает таймер обновления токена.
  ///
  /// [context] — BuildContext для доступа к AuthBloc.
  /// Вызывать после успешной авторизации.
  void init(BuildContext context) {
    _context = context;
    _scheduleRefresh();
    // print('✅ TokenService: инициализирован');
  }

  /// Синхронно возвращает текущий токен из локального хранилища.
  ///
  /// Используйте в UI-слое когда нет доступа к [AuthBloc].
  /// Страницы должны импортировать только [TokenService], не [HiveService].
  static String? get currentToken =>
      HiveService.getUserData('token') as String?;

  /// Останавливает таймер (при logout).
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _context = null;
    // print('🛑 TokenService: остановлен');
  }

  /// Планирует следующее обновление токена на основе текущего токена из Hive.
  void _scheduleRefresh() {
    _refreshTimer?.cancel();

    final token = HiveService.getUserData('token') as String?;
    if (token == null || token.isEmpty) {
      // print('⚠️ TokenService: токен не найден, таймер не запущен');
      return;
    }

    final expiresAt = _getTokenExpiry(token);
    if (expiresAt == null) {
      // print('⚠️ TokenService: не удалось декодировать exp из токена');
      // Fallback: обновляем через 55 минут (токен живёт 1 час)
      _startTimer(const Duration(minutes: 55));
      return;
    }

    final now = DateTime.now();
    final timeUntilExpiry = expiresAt.difference(now);
    final timeUntilRefresh =
        timeUntilExpiry - Duration(seconds: _refreshBeforeExpireSeconds);

    // print('🕐 TokenService: токен истекает в ${expiresAt.toLocal()}');
    // print('🕐 TokenService: до истечения: ${timeUntilExpiry.inMinutes} мин');

    if (timeUntilRefresh.isNegative ||
        timeUntilRefresh.inSeconds < _minTokenLifetimeSeconds) {
      // Токен уже истёк или истекает очень скоро — обновляем немедленно
      // print('⚡ TokenService: токен истекает скоро, обновляем немедленно');
      _doRefresh();
    } else {
      // print();
      _startTimer(timeUntilRefresh);
    }
  }

  /// Запускает таймер с указанной задержкой.
  void _startTimer(Duration delay) {
    _refreshTimer = Timer(delay, _doRefresh);
  }

  /// Выполняет запрос на обновление токена.
  Future<void> _doRefresh() async {
    // print('🔄 TokenService: выполняем refresh токена...');

    // Защита от слишком частых попыток refresh (debounce)
    final now = DateTime.now();
    final lastAttempt = _lastRefreshAttempt;
    if (lastAttempt != null) {
      final timeSinceLastAttempt = now.difference(lastAttempt).inSeconds;
      if (timeSinceLastAttempt < _minRefreshIntervalSeconds) {
        // print('⏳ TokenService: защита debounce - skip refresh, слишком частые попытки');
        // Перепланируем на позже
        _startTimer(
          Duration(seconds: _minRefreshIntervalSeconds - timeSinceLastAttempt),
        );
        return;
      }
    }

    _lastRefreshAttempt = now;

    final currentToken = HiveService.getUserData('token') as String?;
    if (currentToken == null || currentToken.isEmpty) {
      // print('❌ TokenService: нет токена для refresh');
      _notifyTokenExpired();
      return;
    }

    try {
      final newToken = await ApiService.refreshToken(currentToken);

      if (newToken != null && newToken.isNotEmpty) {
        // print('✅ TokenService: токен успешно обновлён');
        // Уведомляем AuthBloc о новом токене
        _notifyTokenRefreshed(newToken);
        // Планируем следующее обновление
        _scheduleRefresh();
      } else {
        // print('❌ TokenService: refresh вернул пустой токен');
        _notifyTokenExpired();
      }
    } catch (e) {
      // print('❌ TokenService: ошибка при refresh: $e');
      // При ошибке refresh - не сразу выбрасываем TokenExpiredEvent
      // Повторим через 30 секунд
      // print('⏳ TokenService: повторим refresh через 30 секунд');
      _startTimer(const Duration(seconds: 30));
    }
  }

  /// Отправляет событие успешного обновления токена в AuthBloc.
  void _notifyTokenRefreshed(String newToken) {
    if (_context == null) return;
    try {
      _context!.read<AuthBloc>().add(TokenRefreshedEvent(newToken: newToken));
    } catch (e) {
      // print('⚠️ TokenService: не удалось уведомить AuthBloc о refresh: $e');
    }
  }

  /// Отправляет событие истечения токена в AuthBloc.
  void _notifyTokenExpired() {
    if (_context == null) return;
    try {
      _context!.read<AuthBloc>().add(const TokenExpiredEvent());
    } catch (e) {
      // print('⚠️ TokenService: не удалось уведомить AuthBloc об истечении: $e');
    }
  }

  /// Декодирует JWT и возвращает время истечения токена (поле `exp`).
  ///
  /// JWT структура: header.payload.signature
  /// Payload содержит `exp` — Unix timestamp истечения токена.
  DateTime? _getTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Добавляем padding для Base64
      String payload = parts[1];
      switch (payload.length % 4) {
        case 1:
          payload += '===';
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      final exp = json['exp'];
      if (exp == null) return null;

      // exp — Unix timestamp в секундах
      return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    } catch (e) {
      // print('❌ TokenService: ошибка декодирования JWT: $e');
      return null;
    }
  }

  /// Принудительно обновляет токен (например, после получения 401).
  ///
  /// Возвращает новый токен или null если refresh не удался.
  /// Применяет защиту от частых обновлений (debounce).
  Future<String?> forceRefresh() async {
    // print('⚡ TokenService: принудительное обновление токена...');

    // Защита от слишком частых попыток refresh
    final now = DateTime.now();
    final lastAttempt = _lastRefreshAttempt;
    if (lastAttempt != null) {
      final timeSinceLastAttempt = now.difference(lastAttempt).inSeconds;
      if (timeSinceLastAttempt < _minRefreshIntervalSeconds) {
        // print('⏳ TokenService: защита debounce - skip, слишком частые попытки');
        return HiveService.getUserData('token') as String?;
      }
    }

    _lastRefreshAttempt = now;

    final currentToken = HiveService.getUserData('token') as String?;
    if (currentToken == null || currentToken.isEmpty) return null;

    try {
      final newToken = await ApiService.refreshToken(currentToken);
      if (newToken != null && newToken.isNotEmpty) {
        // print('✅ TokenService: принудительный refresh успешен');
        _notifyTokenRefreshed(newToken);
        _scheduleRefresh(); // Перепланируем таймер
        return newToken;
      }
    } catch (e) {
      // print('❌ TokenService: принудительный refresh не удался: $e');
    }

    _notifyTokenExpired();
    return null;
  }
}
