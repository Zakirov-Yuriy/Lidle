// ============================================================
// "Сервис: Управление жизненным циклом токена"
//
// Отвечает за:
// 1. Проактивное обновление токена (за 5 минут до истечения)
// 2. Декодирование JWT для получения времени истечения
// 3. Уведомление AuthBloc об истечении / обновлении токена
// 4. Обработку жизненного цикла приложения (foreground/background)
// 5. Защиту от race condition с ApiService._retryRequest()
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../hive_service.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import 'api_service.dart';

/// Сервис управления жизненным циклом токена.
///
/// Принцип работы:
/// - НОВОЕ: Обновляет токен каждый час профилактически (proactive refresh)
/// - За [_refreshBeforeExpireSeconds] до истечения вызывает POST /auth/refresh-token
/// - НОВОЕ: Retry логика с экспоненциальной задержкой при сетевых ошибках
/// - Если refresh успешен — сохраняет новые токены и перезапускает таймер
/// - Если refresh не удался — уведомляет AuthBloc об истечении
/// - Слушает [AppLifecycleState.resumed] и перепроверяет токен при выходе из фона
/// - Предотвращает race condition: ждёт завершения parallel-refresh из ApiService
class TokenService with WidgetsBindingObserver {
  /// За сколько секунд до истечения токена делать refresh (5 минут)
  static const int _refreshBeforeExpireSeconds = 5 * 60;

  /// Минимальное время жизни токена для запуска таймера (30 секунд)
  static const int _minTokenLifetimeSeconds = 30;

  /// Минимальный интервал между попытками refresh (debounce, в секундах)
  static const int _minRefreshIntervalSeconds = 2;

  /// Профилактическое обновление токена каждый час (защита от истечения)
  /// даже если сохраненное время истечения говорит иное
  static const Duration _hourlyRefreshInterval = Duration(hours: 1);

  /// Fallback-таймер когда token_expires_at не найден в Hive:
  /// Используем короткое время (2 мин) — безопаснее обновить раньше, чем пропустить.
  static const Duration _fallbackRefreshDelay = Duration(minutes: 2);

  /// Максимальное количество попыток retry при сетевых ошибках
  static const int _maxRetryAttempts = 3;

  Timer? _refreshTimer;
  BuildContext? _context;
  DateTime? _lastRefreshAttempt;
  DateTime? _hourlyRefreshStartTime;

  /// Флаг: предотвращает запуск параллельного refresh внутри TokenService.
  bool _isRefreshing = false;

  /// Текущее количество попыток retry для текущего обновления
  int _retryAttempt = 0;

  /// Singleton
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  /// Инициализирует сервис: сохраняет context, регистрирует lifecycle observer
  /// и запускает таймер обновления токена.
  ///
  /// [context] — BuildContext для доступа к AuthBloc.
  /// Вызывать после успешной авторизации (когда AuthAuthenticated эмитируется).
  void init(BuildContext context) {
    _context = context;
    // Снять предыдущую подписку (если была) и добавить новую,
    // чтобы не накапливать дублирующие слушатели.
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    _scheduleRefresh();
  }

  /// Слушаем жизненный цикл приложения.
  ///
  /// При переходе в foreground ([AppLifecycleState.resumed]) НЕМЕДЛЕННО проверяем
  /// токен — он мог истечь пока приложение было в фоне (Dart изолят приостановлен).
  /// Это критично для пользователей, которые закрывают приложение на ночь.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print(
        '🔁 TokenService: приложение возвращается из фона, проверяем токен...',
      );
      // Немедленно проверяем и обновляем токен если нужно
      _scheduleRefresh();
    }
  }

  /// Синхронно возвращает текущий токен из локального хранилища.
  ///
  /// Используйте в UI-слое когда нет доступа к [AuthBloc].
  static String? get currentToken =>
      HiveService.getUserData('token') as String?;

  /// Останавливает таймер и снимает lifecycle observer (при logout).
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _context = null;
    _isRefreshing = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Планирует следующее обновление токена на основе [token_expires_at] из Hive
  /// с учетом профилактического обновления каждый час.
  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _retryAttempt = 0; // Сброс счетчика retry при переплане

    final token = HiveService.getUserData('token') as String?;
    if (token == null || token.isEmpty) {
      // Нет токена — возможно выполнен logout, ничего не делаем
      return;
    }

    final now = DateTime.now();

    // НОВОЕ: Профилактическое обновление каждый час (защита от истечения)
    // Даже если сохраненное время истечения говорит иное
    final hourlyRefreshStart = _hourlyRefreshStartTime ?? now;
    _hourlyRefreshStartTime = hourlyRefreshStart;
    final timeSinceHourlyStart = now.difference(hourlyRefreshStart);

    Duration nextRefreshDelay = _hourlyRefreshInterval - timeSinceHourlyStart;

    // Проверяем время до истечения токена
    final expiresAt = _getTokenExpiry(token);
    if (expiresAt != null) {
      final timeUntilExpiry = expiresAt.difference(now);
      final timeUntilRefreshByExpiry =
          timeUntilExpiry -
          const Duration(seconds: _refreshBeforeExpireSeconds);

      if (timeUntilRefreshByExpiry.isNegative ||
          timeUntilRefreshByExpiry.inSeconds < _minTokenLifetimeSeconds) {
        // Токен истекает скоро — обновляем немедленно вместо отложенного обновления
        nextRefreshDelay = Duration.zero;
      } else if (timeUntilRefreshByExpiry < nextRefreshDelay) {
        // Если истечение токена приходит раньше часового интервала — используем его
        nextRefreshDelay = timeUntilRefreshByExpiry;
      }
    }

    if (nextRefreshDelay.inSeconds <= 0) {
      // Обновляем немедленно
      _doRefresh();
    } else {
      _startTimer(nextRefreshDelay);
    }
  }

  /// Запускает таймер с указанной задержкой.
  void _startTimer(Duration delay) {
    _refreshTimer = Timer(delay, _doRefresh);
  }

  /// Выполняет запрос на обновление токена с retry логикой при сетевых ошибках.
  ///
  /// Содержит защиту от:
  /// 1. Параллельных вызовов внутри TokenService ([_isRefreshing])
  /// 2. Слишком частых попыток (debounce [_minRefreshIntervalSeconds])
  /// 3. Race condition с ApiService._retryRequest() — ожидает уже активный refresh
  /// 4. Сетевых ошибок — retry с экспоненциальной задержкой перед тем как отправить на авторизацию
  Future<void> _doRefresh() async {
    // Защита #1: предотвращаем параллельный refresh внутри TokenService
    if (_isRefreshing) return;

    // Защита #2: debounce — не запускаем refresh чаще чем раз в N секунд
    final now = DateTime.now();
    final lastAttempt = _lastRefreshAttempt;
    if (lastAttempt != null) {
      final elapsed = now.difference(lastAttempt).inSeconds;
      if (elapsed < _minRefreshIntervalSeconds) {
        _startTimer(Duration(seconds: _minRefreshIntervalSeconds - elapsed));
        return;
      }
    }

    // Защита #3: race condition — если ApiService уже выполняет refresh (например,
    // из-за 401 на API-запросе), ждём его завершения вместо запуска второго refresh.
    // Без этого оба вызова берут один refresh_token из Hive, первый его ротирует,
    // второй получает 403 → _notifyTokenExpired() → пользователь выброшен из приложения.
    if (ApiService.isRefreshingToken) {
      final newToken = await ApiService.waitForPendingRefresh();
      if (newToken != null && newToken.isNotEmpty) {
        // Параллельный refresh уже завершился успешно — используем его результат
        _notifyTokenRefreshed(newToken);
        _scheduleRefresh();
      } else {
        // Параллельный refresh провалился — повторим сами через 5 секунд
        _startTimer(const Duration(seconds: 5));
      }
      return;
    }

    _isRefreshing = true;
    _lastRefreshAttempt = now;

    final currentToken = HiveService.getUserData('token') as String?;
    if (currentToken == null || currentToken.isEmpty) {
      _isRefreshing = false;
      _notifyTokenExpired();
      return;
    }

    try {
      final newToken = await ApiService.refreshToken(currentToken);

      if (newToken != null && newToken.isNotEmpty) {
        // Refresh успешен — уведомляем AuthBloc и планируем следующее обновление
        print('✅ TokenService: токен успешно обновлен');
        _retryAttempt = 0; // Уменьшаем счетчик retry после успеха
        _notifyTokenRefreshed(newToken);
        _scheduleRefresh();
      } else {
        // refreshToken() вернул null: refresh_token истёк или невалиден на сервере (401/403).
        // Это постоянная ошибка — повторные попытки не помогут, нужна повторная авторизация.
        print('❌ TokenService: refresh_token невалиден (401/403 на сервере)');
        _notifyTokenExpired();
      }
    } catch (e) {
      // Сетевая ошибка, таймаут или другая временная проблема
      print('⚠️  TokenService: ошибка при обновлении токена: $e');

      // НОВОЕ: Retry логика с экспоненциальной задержкой
      _retryAttempt++;
      if (_retryAttempt < _maxRetryAttempts) {
        // Пытаемся еще раз с растущей задержкой: 1 сек, 2 сек, 4 сек
        final delaySeconds = (1 << (_retryAttempt - 1)).clamp(1, 5);
        print(
          '🔄 TokenService: retry попытка $_retryAttempt/$_maxRetryAttempts через ${delaySeconds}с',
        );
        _startTimer(Duration(seconds: delaySeconds));
      } else {
        // Исчерпали все попытки retry — отправляем пользователя на авторизацию
        print(
          '❌ TokenService: исчерпаны все попытки retry ($_maxRetryAttempts), отправляем на авторизацию',
        );
        _notifyTokenExpired();
      }
    } finally {
      _isRefreshing = false;
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
  /// Sanctum opaque токены (формат "153|abc...") НЕ являются JWT и не могут
  /// быть декодированы. Для них используется fallback: время истечения читается
  /// из Hive (ключ `token_expires_at`), куда его сохраняет ApiService.refreshToken()
  /// и auth_bloc.dart при успешном логине.
  DateTime? _getTokenExpiry(String token) {
    // Пробуем декодировать как JWT (header.payload.signature)
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
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
        if (exp != null) {
          // exp — Unix timestamp в секундах
          return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
        }
      }
    } catch (_) {
      // Не JWT — это Sanctum opaque token (формат: "153|abc..."), игнорируем
    }

    // Fallback для Sanctum токенов: читаем сохранённое время истечения из Hive.
    // Значение устанавливается в ApiService.refreshToken() и auth_bloc.dart при логине.
    final savedExpiresAt = HiveService.getUserData('token_expires_at');
    if (savedExpiresAt != null) {
      // Может быть int или String (auth_bloc сохраняет через UserService.saveLocal)
      final ms = savedExpiresAt is int
          ? savedExpiresAt
          : int.tryParse(savedExpiresAt.toString());
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }

    return null;
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
