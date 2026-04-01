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
import 'package:lidle/core/logger.dart';

/// Сервис управления жизненным циклом токена.
///
/// Принцип работы:
/// - Обновляет ОБА токена (access_token и refresh_token):
///   * access_token: за 5 минут до истечения (действует 15 минут)
///   * refresh_token: за 24 часа до истечения (действует 14 дней)
/// - КРИТИЧНО: Если refresh_token истечет, пользователь не сможет обновить access_token
/// - Профилактическое обновление каждый час (дополнительная защита
/// - Retry логика с экспоненциальной задержкой при сетевых ошибках
/// - Если оба токена истекли → пользователь отправляется на login
/// - Если refresh успешен — сохраняет новые токены и перезапускает таймер
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
      log.d(
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

  /// Планирует следующее обновление токена на основе [token_expires_at] и [refresh_token_expires_at] из Hive
  /// с учетом профилактического обновления каждый час.
  /// 
  /// ОБНОВЛЕНО: Теперь проверяет оба токена:
  /// - access_token: обновляем за 5 минут до истечения
  /// - refresh_token: обновляем за 24 часа до истечения (критично! без него доступ теряется)
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

    // Проверяем время до истечения ACCESS_TOKEN
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

    // ОБНОВЛЕНО: Проверяем время до истечения REFRESH_TOKEN
    // Это критично! Если refresh_token истечет, мы не сможем обновить access_token.
    // Поэтому обновляем заранее на 24 часа.
    final refreshTokenExpiresAt = _getRefreshTokenExpiry();
    if (refreshTokenExpiresAt != null) {
      final timeUntilRefreshTokenExpiry = refreshTokenExpiresAt.difference(now);
      const refreshTokenRefreshBefore = Duration(hours: 24); // Обновляем за 24 часа
      
      final timeUntilRefreshTokenRefresh = timeUntilRefreshTokenExpiry - refreshTokenRefreshBefore;

      if (timeUntilRefreshTokenRefresh.isNegative ||
          timeUntilRefreshTokenRefresh.inSeconds < _minTokenLifetimeSeconds) {
        // Refresh_token истекает скоро — обновляем немедленно
        log.d(
          '⚠️ TokenService: refresh_token истекает через ${timeUntilRefreshTokenExpiry.inHours}ч, обновляем немедленно',
        );
        nextRefreshDelay = Duration.zero;
      } else if (timeUntilRefreshTokenRefresh < nextRefreshDelay) {
        // Если истечение refresh_token приходит раньше — используем его
        log.d(
          '📅 TokenService: планируем refresh за ${timeUntilRefreshTokenRefresh.inHours}ч до истечения refresh_token',
        );
        nextRefreshDelay = timeUntilRefreshTokenRefresh;
      }
    } else {
      // refresh_token_expires_at не найден (может быть старые данные)
      // Используем fallback: короткий интервал для безопасности
      log.d('⚠️ TokenService: refresh_token_expires_at не найден, используем fallback 2h');
      nextRefreshDelay = const Duration(hours: 2);
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
    final refreshToken = HiveService.getUserData('refresh_token') as String?;
    
    if (currentToken == null || currentToken.isEmpty) {
      _isRefreshing = false;
      log.d('❌ TokenService: access_token не найден в Hive');
      _notifyTokenExpired();
      return;
    }
    
    if (refreshToken == null || refreshToken.isEmpty) {
      _isRefreshing = false;
      log.d('❌ TokenService: refresh_token не найден в Hive - невозможно обновить токен!');
      _notifyTokenExpired();
      return;
    }

    try {
      final newToken = await ApiService.refreshToken(currentToken);

      if (newToken != null && newToken.isNotEmpty) {
        // Refresh успешен — уведомляем AuthBloc и планируем следующее обновление
        log.d('✅ TokenService: токен успешно обновлен');
        _retryAttempt = 0; // Уменьшаем счетчик retry после успеха
        _notifyTokenRefreshed(newToken);
        _scheduleRefresh();
      } else {
        // refreshToken() вернул null: refresh_token истёк или невалиден на сервере (401/403).
        // Это постоянная ошибка — повторные попытки не помогут, нужна повторная авторизация.
        log.d('❌ TokenService: refresh_token невалиден на сервере (401/403) - требуется повторная авторизация');
        _notifyTokenExpired();
      }
    } catch (e) {
      // Сетевая ошибка, таймаут или другая временная проблема
      log.d('⚠️  TokenService: ошибка при обновлении токена: $e');

      // НОВОЕ: Retry логика с экспоненциальной задержкой
      _retryAttempt++;
      if (_retryAttempt < _maxRetryAttempts) {
        // Пытаемся еще раз с растущей задержкой: 1 сек, 2 сек, 4 сек
        final delaySeconds = (1 << (_retryAttempt - 1)).clamp(1, 5);
        log.d(
          '🔄 TokenService: retry попытка $_retryAttempt/$_maxRetryAttempts через ${delaySeconds}с',
        );
        _startTimer(Duration(seconds: delaySeconds));
      } else {
        // Исчерпали все попытки retry — отправляем пользователя на авторизацию
        log.d(
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
      // log.d('⚠️ TokenService: не удалось уведомить AuthBloc о refresh: $e');
    }
  }

  /// Отправляет событие истечения токена в AuthBloc.
  void _notifyTokenExpired() {
    if (_context == null) return;
    try {
      _context!.read<AuthBloc>().add(const TokenExpiredEvent());
    } catch (e) {
      // log.d('⚠️ TokenService: не удалось уведомить AuthBloc об истечении: $e');
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

  /// Получает время истечения refresh_token из Hive (ключ: refresh_token_expires_at)
  /// или возвращает null если данные не доступны.
  ///
  /// Refresh_token — это Sanctum opaque token (формат: "918|..."),
  /// который НЕ можно декодировать. Время истечения получась из:
  /// 1. Сохраненного значения refresh_token_expires_at в Hive (установлено ApiService.refreshToken())
  /// 2. Fallback: null (будет использована защита debounce и 24-часовой interval)
  ///
  /// ВАЖНО для UX:
  /// - Если refresh_token истечет, пользователь потеряет доступ к приложению
  /// - Поэтому обновляем его за 24 часа до истечения (очень консервативно, но безопасно)
  /// - Это гарантирует что пользователь никогда не столкнется с 401 при выполнении действия
  DateTime? _getRefreshTokenExpiry() {
    final savedExpiresAt = HiveService.getUserData('refresh_token_expires_at');
    if (savedExpiresAt != null) {
      // Может быть int или String (зависит от того кто сохранял)
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
    // log.d('⚡ TokenService: принудительное обновление токена...');

    // Защита от слишком частых попыток refresh
    final now = DateTime.now();
    final lastAttempt = _lastRefreshAttempt;
    if (lastAttempt != null) {
      final timeSinceLastAttempt = now.difference(lastAttempt).inSeconds;
      if (timeSinceLastAttempt < _minRefreshIntervalSeconds) {
        // log.d('⏳ TokenService: защита debounce - skip, слишком частые попытки');
        return HiveService.getUserData('token') as String?;
      }
    }

    _lastRefreshAttempt = now;

    final currentToken = HiveService.getUserData('token') as String?;
    if (currentToken == null || currentToken.isEmpty) return null;

    try {
      final newToken = await ApiService.refreshToken(currentToken);
      if (newToken != null && newToken.isNotEmpty) {
        // log.d('✅ TokenService: принудительный refresh успешен');
        _notifyTokenRefreshed(newToken);
        _scheduleRefresh(); // Перепланируем таймер
        return newToken;
      }
    } catch (e) {
      // log.d('❌ TokenService: принудительный refresh не удался: $e');
    }

    _notifyTokenExpired();
    return null;
  }
}
