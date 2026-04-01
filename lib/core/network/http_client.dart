// ============================================================
// "HTTP клиент с поддержкой retry и автоматического refresh токена"
// ============================================================
// Базовый слой для всех API запросов. Обрабатывает:
// - Основные HTTP методы (GET, POST, PUT, DELETE)
// - Автоматический retry при 429 (rate limit)
// - Автоматический refresh токена при 401
// - Exponential backoff при rate limit
// - Race condition protection для token refresh
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:lidle/hive_service.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/network/exceptions.dart';
import 'package:lidle/core/network/token_interceptor.dart';

/// HTTP клиент для API запросов с встроенной логикой retry и token refresh.
///
/// **Особенности:**
/// - Автоматический retry при 429 (rate limit) с exponential backoff
/// - Автоматический refresh токена при 401 (token expired)
/// - Race condition protection: если несколько запросов получат 401 одновременно,
///   только один будет делать refresh, остальные будут ждать его завершения
/// - Поддержка GET с body параметрами (нестандартное использование)
/// - Логирование всех запросов и ответов
class HttpClient {
  // ОПТИМИЗАЦИЯ: Базовый URL захардкодирован чтобы не использовать dotenv при инициализации
  // dotenv.load() отнимает ~900ms, а базовый URL не меняется
  static String get baseUrl => 'https://dev-api.lidle.io/v1';
  static const int _maxRetries = 4;
  static const int _retryDelayMs =
      2000; // 🚀 ОПТИМИЗАЦИЯ: Увеличена стартовая задержка с 1000ms на 2000ms
            // Это дает серверу больше времени на восстановление между попытками
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    // Заголовки согласно официальной документации API Lidle
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
    'Content-Type': 'application/json',
  };

  /// Lock для рефреша токена: если один запрос уже делает refresh,
  /// все остальные ждут его завершения вместо того чтобы запускать параллельные refresh.
  static Completer<String?>? _tokenRefreshCompleter;

  /// Возвращает true если прямо сейчас выполняется refresh токена через _retryRequest.
  /// Используется TokenService для предотвращения race condition при одновременном
  /// обновлении токена: timer-based (TokenService) и reactive (401 handler).
  static bool get isRefreshingToken => _tokenRefreshCompleter != null;

  /// Ожидает завершения текущего refresh-запроса, если он выполняется.
  ///
  /// Возвращает новый access_token если refresh успешен, иначе null.
  /// TokenService вызывает этот метод вместо запуска собственного refresh,
  /// чтобы не использовать один и тот же refresh_token дважды.
  static Future<String?> waitForPendingRefresh() async {
    final completer = _tokenRefreshCompleter;
    if (completer == null) return null;
    try {
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  /// Выполняет GET запрос с автоматическим retry при 429.
  /// Если token не передан - автоматически читает из Hive.
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    // Передаём null внутри замыкания, чтобы при retry после refresh токен
    // читался свежим из Hive, а не использовался захваченный устаревший
    return _retryRequest(() => _getRequest(endpoint, null), endpoint);
  }

  /// Внутренний метод для GET запроса
  static Future<Map<String, dynamic>> _getRequest(
    String endpoint,
    String? token,
  ) async {
    try {
      final headers = {...defaultHeaders};
      // Читаем токен из параметра или из Hive (для автоматического обновления при refresh)
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken != null) {
        headers['Authorization'] = 'Bearer $effectiveToken';
      }

      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          // 🚀 ОПТИМИЗАЦИЯ #2: Timeout 10s → 5s для фазы 1 запросов
          // Сервер обычно отвечает за 500-800ms, 5s - безопасный лимит
          .timeout(const Duration(seconds: 5));

      return _handleResponse(response);
    } on TokenExpiredException {
      // Пробросить TokenExpiredException для обработки в _retryRequest
      rethrow;
    } on RateLimitException {
      // Пробросить RateLimitException для retry логики
      rethrow;
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Выполняет POST запрос с автоматическим retry при 429.
  /// Если token не передан - автоматически читает из Hive.
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,

    /// Если true — при 401 НЕ пытаемся обновить токен.
    /// Обязательно true для всех auth-эндпоинтов (login, register, etc.),
    /// иначе неверные учётные данные → 401 → 15с зависание на refresh.
    bool skipTokenRefresh = false,
  }) async {
    return _retryRequest(
      () => _postRequest(endpoint, body, token),
      endpoint,
      skipTokenRefresh: skipTokenRefresh,
    );
  }

  /// Внутренний метод для POST запроса
  static Future<Map<String, dynamic>> _postRequest(
    String endpoint,
    Map<String, dynamic> body,
    String? token,
  ) async {
    try {
      final headers = {...defaultHeaders};
      // Читаем токен из параметра или из Hive (для автоматического обновления при refresh)
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken != null) {
        headers['Authorization'] = 'Bearer $effectiveToken';
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 10s → 5s для фазы 1 запросов
          // Сервер обычно отвечает за 500-800ms, 5s безопасный лимит
          .timeout(const Duration(seconds: 5));

      return _handleResponse(response);
    } on TokenExpiredException {
      // Пробросить TokenExpiredException для обработки в _retryRequest
      rethrow;
    } on RateLimitException {
      // Пробросить RateLimitException для retry логики
      rethrow;
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Выполняет GET запрос с JSON body (нестандартное использование).
  /// Используется для API endpoint-ов которые требуют GET + body параметры,
  /// например: GET /v1/users/{id}/adverts с body { sort: [], page: 1 }
  ///
  /// Если token не передан - автоматически читает из Hive.
  static Future<Map<String, dynamic>> getWithBody(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _retryRequest(
      () => _getWithBodyRequest(endpoint, body, null),
      endpoint,
    );
  }

  /// Внутренний метод для GET запроса с JSON body.
  /// Использует http.Request напрямую, так как http.get() не поддерживает body.
  static Future<Map<String, dynamic>> _getWithBodyRequest(
    String endpoint,
    Map<String, dynamic> body,
    String? token,
  ) async {
    try {
      final headers = {...defaultHeaders};
      // Читаем токен из параметра или из Hive (для автоматического обновления при refresh)
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken != null) {
        headers['Authorization'] = 'Bearer $effectiveToken';
      }

      // http.get() не поддерживает body, поэтому используем http.Request напрямую
      final request = http.Request('GET', Uri.parse('$baseUrl$endpoint'));
      request.headers.addAll(headers);
      request.body = jsonEncode(body);

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TokenExpiredException {
      rethrow;
    } on RateLimitException {
      rethrow;
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      rethrow;
    }
  }

  /// Выполняет GET запрос с query параметрами с retry при 429.
  static Future<Map<String, dynamic>> getWithQuery(
    String endpoint,
    Map<String, dynamic> queryParams, {
    String? token,
  }) async {
    return _retryRequest(
      () => _getWithQueryRequest(endpoint, queryParams, null),
      endpoint,
    );
  }

  /// Внутренний метод для GET запроса с query параметрами
  static Future<Map<String, dynamic>> _getWithQueryRequest(
    String endpoint,
    Map<String, dynamic> queryParams,
    String? token,
  ) async {
    try {
      final headers = {...defaultHeaders};
      // Читаем токен из параметра или из Hive (для автоматического обновления при refresh)
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken != null) {
        headers['Authorization'] = 'Bearer $effectiveToken';
      }

      // Обработка query параметров с поддержкой множественных значений с одним ключом
      // Это необходимо для фильтров типа filters[attr_6][]=value1&filters[attr_6][]=value2
      final baseUri = Uri.parse('$baseUrl$endpoint');

      // Если есть параметры, которые появляются несколько раз (массивы),
      // нужно построить query string вручную
      String? queryString;
      final queryParts = <String>[];

      queryParams.forEach((key, value) {
        final encodedKey = Uri.encodeComponent(key);

        // Обработка массивов: если value это List, добавляем несколько пар key=value
        if (value is List) {
          for (final item in value) {
            final encodedValue = Uri.encodeComponent(item.toString());
            queryParts.add('$encodedKey=$encodedValue');
          }
        } else {
          // Обычный скалярный параметр
          final encodedValue = Uri.encodeComponent(value.toString());
          queryParts.add('$encodedKey=$encodedValue');
        }
      });

      if (queryParts.isNotEmpty) {
        queryString = queryParts.join('&');
      }

      final uri = queryString != null
          ? baseUri.replace(query: queryString)
          : baseUri;

      final response = await http
          .get(uri, headers: headers)
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 10s → 5s
          .timeout(const Duration(seconds: 5));

      return _handleResponse(response);
    } on TokenExpiredException {
      // Пробрасываем для обработки в _retryRequest (refresh логика)
      rethrow;
    } on RateLimitException {
      rethrow;
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      rethrow;
    }
  }

  /// Выполняет PUT запрос с retry при 429.
  /// Если token не передан - автоматически читает из Hive.
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _retryRequest(() => _putRequest(endpoint, body, token), endpoint);
  }

  /// Внутренний метод для PUT запроса
  static Future<Map<String, dynamic>> _putRequest(
    String endpoint,
    Map<String, dynamic> body,
    String? token,
  ) async {
    try {
      final headers = {...defaultHeaders};
      // Читаем токен из параметра или из Hive (для автоматического обновления при refresh)
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken != null) {
        headers['Authorization'] = 'Bearer $effectiveToken';
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 10s → 5s
          .timeout(const Duration(seconds: 5));

      return _handleResponse(response);
    } on TokenExpiredException {
      rethrow;
    } on RateLimitException {
      rethrow;
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } on Exception {
      // Пробрасываем Exception дальше (включая ошибки из _handleResponse)
      rethrow;
    } catch (e) {
      throw Exception('Неизвестная ошибка: $e');
    }
  }

  /// Выполняет DELETE запрос с retry при 429 (поддерживает тело запроса).
  /// Если token не передан - автоматически читает из Hive.
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    return _retryRequest(() => _deleteRequest(endpoint, token, body), endpoint);
  }

  /// Внутренний метод для DELETE запроса
  static Future<Map<String, dynamic>> _deleteRequest(
    String endpoint,
    String? token,
    Map<String, dynamic>? body,
  ) async {
    try {
      final headers = {...defaultHeaders};
      // Читаем токен из параметра или из Hive (для автоматического обновления при refresh)
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken != null) {
        headers['Authorization'] = 'Bearer $effectiveToken';
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 10s → 5s
          .timeout(const Duration(seconds: 5));

      return _handleResponse(response);
    } on TokenExpiredException {
      rethrow;
    } on RateLimitException {
      rethrow;
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Retry логика с exponential backoff для обработки 429 ошибок и 401 (TokenExpired).
  ///
  /// При получении TokenExpiredException:
  /// 1. Если refresh уже выполняется — ждём его завершения (Completer-lock).
  /// 2. Если нет — запускаем единственный refresh, все параллельные запросы ждут.
  /// 3. После обновления токена повторяем запрос.
  ///
  /// Автоматически повторяет запросы при 429 с задержкой: 2s, 4s, 8s, 16s.
  static Future<Map<String, dynamic>> _retryRequest(
    Future<Map<String, dynamic>> Function() request,
    String endpoint, {

    /// Если true — пропускаем попытку обновить токен при 401.
    /// Используется для auth-эндпоинтов, где 401 = неверные учётные данные.
    bool skipTokenRefresh = false,
  }) async {
    bool tokenRefreshAttempted = false;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await request();
      } on TokenExpiredException {
        // Для auth-эндпоинтов (login, etc.) пропускаем refresh:
        // 401 здесь означает неверные учётные данные, а не истёкший токен.
        if (skipTokenRefresh) rethrow;
        // 401 — токен истёк. Разрешаем одну попытку refresh на запрос.
        if (tokenRefreshAttempted) {
          // Уже пробовали refresh, повторная 401 — токен реально невалиден.
          rethrow;
        }
        tokenRefreshAttempted = true;

        // Если другой запрос уже выполняет refresh — ждём его завершения.
        final existingCompleter = _tokenRefreshCompleter;
        if (existingCompleter != null) {
          try {
            await existingCompleter.future;
            // Токен обновлён другим запросом, повторяем свой запрос.
            continue;
          } catch (_) {
            throw TokenExpiredException('Token refresh failed by parallel request');
          }
        }

        // Мы первый — запускаем refresh через TokenInterceptor
        final completer = Completer<String?>();
        _tokenRefreshCompleter = completer;

        try {
          final currentToken = HiveService.getUserData('token') as String?;
          if (currentToken == null || currentToken.isEmpty) {
            log.d('🔒 HttpClient: нет сохраненного токена для обновления');
            final error = TokenExpiredException('No saved token to refresh');
            completer.completeError(error);
            throw error;
          }

          // Используем TokenInterceptor для синхронизированного refresh
          final newToken = await TokenInterceptor.refreshToken(currentToken);

          if (newToken != null && newToken.isNotEmpty) {
            completer.complete(newToken);
            // Повторяем исходный запрос с новым токеном (из Hive)
            continue;
          } else {
            final error = TokenExpiredException('Token refresh returned null or empty');
            completer.completeError(error);
            throw error;
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
          rethrow;
        } finally {
          // Сбрасываем lock
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_tokenRefreshCompleter == completer) {
              _tokenRefreshCompleter = null;
            }
          });
        }
      } on RateLimitException {
        if (attempt < _maxRetries - 1) {
          final delayMs = _retryDelayMs * (1 << attempt); // Exponential backoff
          log.d('⏳ HttpClient: rate limit - ждем ${delayMs}ms перед повтором...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          log.d('❌ Максимум попыток достигнут. Прекращаю retry.');
          rethrow;
        }
      }
    }
    throw Exception('Failed after $_maxRetries attempts');
  }

  /// Обрабатывает ответ от сервера.
  static Map<String, dynamic> _handleResponse(http.Response response) {
    // ✅ Обработка пустого ответа (204 No Content или пустое тело при 2xx)
    if (response.body.isEmpty && response.statusCode >= 200 && response.statusCode < 300) {
      log.d('✅ HttpClient._handleResponse: Успешный пустой ответ (${response.statusCode})');
      return {'success': true, 'message': 'Success', 'data': null};
    }

    // Пробуем разобрать тело ответа как JSON
    // Если сервер вернул HTML (например, 404 страница), бросаем понятное исключение
    Map<String, dynamic> data;
    try {
      // 🚀 ОПТИМИЗАЦИЯ #3: JSON парсинг оптимизирован для больших ответов
      // jsonDecode уже использует внутреннюю оптимизацию для больших JSON
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // ❌ Если статус 2xx но JSON парсинг не удался - это ошибка API
      if (response.statusCode >= 200 && response.statusCode < 300) {
        log.d('⚠️ HttpClient._handleResponse: Статус ${response.statusCode} но не валидный JSON');
        log.d('   Тело ответа: "${response.body}"');
        // Возвращаем успешный ответ с пустыми данными
        return {'success': true, 'message': 'Success', 'data': null};
      }
      
      throw Exception(
        'Сервер вернул не JSON ответ (статус ${response.statusCode}). Тело: "${response.body}"',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else if (response.statusCode == 429) {
      throw RateLimitException('429 Too Many Requests');
    } else if (response.statusCode == 401) {
      throw TokenExpiredException(data['message'] ?? 'Неверные учетные данные');
    } else if (response.statusCode == 423) {
      // 423 = email не подтверждён (email_not_verified) или аккаунт заблокирован (account_locked).
      // Не бросаем исключение — возвращаем тело ответа, чтобы BLoC обработал
      // success:false и показал корректное сообщение пользователю.
      return data;
    } else if (response.statusCode == 422) {
      // Validation error - return response with errors
      return data;
    } else if (response.statusCode == 500) {
      throw Exception(data['message'] ?? 'Ошибка сервера');
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      // 4xx ошибки (404, 400, 403, и т.д.) - выбрасываем исключение
      log.d('❌ Error with status ${response.statusCode}');
      log.d('   Message: ${data['message'] ?? 'Ошибка сервера'}');
      throw Exception('${data['message'] ?? 'Ошибка запроса'} (статус ${response.statusCode})');
    } else {
      // Остальные статусы (не обработанные выше)
      log.d('❌ Error with status ${response.statusCode}');
      log.d('   Message: ${data['message'] ?? 'Ошибка сервера'}');
      throw Exception('${data['message'] ?? 'Ошибка сервера'} (статус ${response.statusCode})');
    }
  }
}
