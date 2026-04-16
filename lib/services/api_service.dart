import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lidle/models/filter_models.dart'; // Import the new model
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/models/catalog_model.dart' as catalog_models;
import 'package:lidle/models/create_advert_model.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/config/app_config.dart';
import 'package:lidle/core/network/http_client.dart';
import 'package:lidle/core/network/token_interceptor.dart';

// Re-export exceptions for backward compatibility
export 'package:lidle/core/network/exceptions.dart';

/// Исключение для 401 ошибок (токен истёк или невалиден).
/// Используется для перехвата и автоматического refresh токена.
class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException([this.message = 'Token expired']);

  @override
  String toString() => 'TokenExpiredException: $message';
}

/// Пользовательское исключение для 429 (rate limit) ошибок
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => 'RateLimitException: $message';
}

/// Базовый класс для работы с API.
/// Обрабатывает общие заголовки и базовый URL.
class ApiService {
  // Получаем базовый URL из конфигурации приложения (dev или prod)
  // Конфигурация загружается из .env файла при старте приложения
  static String get baseUrl => AppConfig().apiBaseUrl;
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

  //   Accept: application/json
  // X-App-Client: mobile
  // X-Client-Platform: web
  // Accept-Language: ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7

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

      // log.d('═══════════════════════════════════════════════════════');
      // log.d('📥 GET REQUEST');
      // log.d('URL: $baseUrl$endpoint');
      // log.d('Token provided: ${effectiveToken != null}');
      if (effectiveToken != null) {
        // log.d('Token preview: ${effectiveToken.substring(0, 30)}...');
        // log.d('Token type: JWT');
      }
      // log.d('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // log.d('  $key: Bearer [HIDDEN]');
        } else {
          // log.d('  $key: $value');
        }
      });
      // log.d('═══════════════════════════════════════════════════════');

      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          // 🚀 ОПТИМИЗАЦИЯ #2: Timeout 5s → 30s
          // Медленное интернет соединение требует больше времени
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } on TokenExpiredException {
      // Пробросить TokenExpiredException для обработки в AuthBloc
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

      // log.d('═══════════════════════════════════════════════════════');
      // log.d('📤 POST REQUEST');
      // log.d('URL: $baseUrl$endpoint');
      // log.d('Token provided: ${effectiveToken != null}');
      // if (effectiveToken != null) {
      //   log.d('Token preview: ${effectiveToken.substring(0, 30)}...');
      //   log.d('Token type: JWT');
      // }
      // log.d('Headers:');
      // headers.forEach((key, value) {
      //   if (key == 'Authorization') {
      //     log.d('  $key: Bearer [HIDDEN]');
      //   } else {
      //     log.d('  $key: $value');
      //   }
      // });
      // log.d('Body: $body');
      // log.d('Body keys: ${body.keys.toList()}');
      // body.forEach((key, value) {
      //   log.d('  $key: $value (type: ${value.runtimeType})');
      // });
      // log.d('═══════════════════════════════════════════════════════');

      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 5s → 30s
          // Медленное интернет соединение требует больше времени
          .timeout(const Duration(seconds: 30));

      // log.d('📥 Response status: ${response.statusCode}');
      // log.d('📥 Response body: ${response.body}');

      return _handleResponse(response);
    } on TokenExpiredException {
      // Пробросить TokenExpiredException для обработки в AuthBloc
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
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 5s → 30s
          // Медленное интернет соединение требует больше времени
          .timeout(const Duration(seconds: 30));

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

      // log.d('═══════════════════════════════════════════════════════');
      // log.d('📤 PUT REQUEST');
      // log.d('URL: $baseUrl$endpoint');
      // log.d('Token provided: ${effectiveToken != null}');
      if (effectiveToken != null) {
        // log.d('Token preview: ${effectiveToken.substring(0, 30)}...');
        // log.d('Token type: JWT');
      }
      // log.d('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // log.d('  $key: Bearer [HIDDEN]');
        } else {
          // log.d('  $key: $value');
        }
      });
      // log.d('Body: $body');
      // log.d('═══════════════════════════════════════════════════════');

      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 5s → 30s
          // Медленное интернет соединение требует больше времени
          .timeout(const Duration(seconds: 30));

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

      // log.d('═══════════════════════════════════════════════════════');
      // log.d('🗑️ DELETE REQUEST');
      // log.d('URL: $baseUrl$endpoint');
      // log.d('Token provided: ${effectiveToken != null}');
      // if (effectiveToken != null) {
      //   log.d('Token preview: ${effectiveToken.substring(0, 30)}...');
      //   log.d('Token type: JWT');
      // }
      // log.d('Headers:');
      // headers.forEach((key, value) {
      //   if (key == 'Authorization') {
      //     log.d('  $key: Bearer [HIDDEN]');
      //   } else {
      //     log.d('  $key: $value');
      //   }
      // });
      // if (body != null) {
      //   log.d('Body: $body');
      // }
      // log.d('═══════════════════════════════════════════════════════');

      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          // 🚀 ОПТИМИЗАЦИЯ: Timeout 5s → 30s
          // Медленное интернет соединение требует больше времени
          .timeout(const Duration(seconds: 30));
      
      // log.d('📥 DELETE RESPONSE received:');
      // log.d('   Status: ${response.statusCode}');
      // log.d('   Body length: ${response.body.length}');
      // if (response.body.isNotEmpty) {
      //   log.d('   Body: ${response.body}');
      // }

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
  /// Автоматически повторяет запросы при 429 с задержкой: 1s, 2s, 4s, 8s.
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
            // log.d('⏳ Ожидаем завершения активного refresh...');
            await existingCompleter.future;
            // Токен обновлён другим запросом, повторяем свой запрос.
            // КРИТИЧНО: Не пробуем еще один refresh - используем токен что обновил параллельный запрос
            continue;
          } catch (_) {
            // Refresh завершился ошибкой — пробрасываем как TokenExpired.
            throw TokenExpiredException(
              'Token refresh failed by parallel request',
            );
          }
        }

        // Мы первый — запускаем refresh и устанавливаем lock.
        final completer = Completer<String?>();
        _tokenRefreshCompleter = completer;

        try {
          final currentToken = HiveService.getUserData('token') as String?;
          if (currentToken == null || currentToken.isEmpty) {
            // Нет сохраненного токена - пользователь не авторизован
            // Не пробуем refresh, просто рапортуем об истечении
            log.d('🔒 ApiService: нет сохраненного токена для обновления');
            final error = TokenExpiredException('No saved token to refresh');
            completer.completeError(error);
            throw error;
          }

          final newToken = await refreshToken(currentToken);

          if (newToken != null && newToken.isNotEmpty) {
            // log.d('✅ ApiService: токен обновлён');
            // КРИТИЧНО: Проверяем что токен действительно сохранен в Hive перед тем как продолжить
            final savedToken = HiveService.getUserData('token') as String?;
            if (savedToken == newToken || (savedToken != null && savedToken.isNotEmpty)) {
              completer.complete(newToken);
              // Повторяем исходный запрос с новым токеном (из Hive).
              continue;
            } else {
              final error = TokenExpiredException(
                'Token was not properly saved to Hive after refresh',
              );
              completer.completeError(error);
              throw error;
            }
          } else {
            final error = TokenExpiredException(
              'Token refresh returned empty token',
            );
            completer.completeError(error);
            throw error;
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
          rethrow;
        } finally {
          // Сбрасываем lock с небольшой задержкой, чтобы ожидающие успели получить результат.
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_tokenRefreshCompleter == completer) {
              _tokenRefreshCompleter = null;
            }
          });
        }
      } on RateLimitException {
        if (attempt < _maxRetries - 1) {
          final delayMs = _retryDelayMs * (1 << attempt); // Exponential backoff
          // log.d('⏳ ApiService: rate limit - ждем ${delayMs}ms перед повтором...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          // log.d('❌ Максимум попыток достигнут. Прекращаю retry.');
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
      log.d('✅ ApiService._handleResponse: Успешный пустой ответ (${response.statusCode})');
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
        log.d('⚠️ ApiService._handleResponse: Статус ${response.statusCode} но не валидный JSON');
        log.d('   Тело ответа: "${response.body}"');
        // Возвращаем успешный ответ с пустыми данными
        return {'success': true, 'message': 'Success', 'data': null};
      }
      
      throw Exception(
        'Сервер вернул не JSON ответ (статус ${response.statusCode}). Тело: "${response.body}"',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // log.d('✅ Request successful!');
      return data;
    } else if (response.statusCode == 429) {
      // Rate limit - signal to retry
      // log.d('⚠️ 429 Too Many Requests - Rate limited');
      // log.d('Error response: ${data['message'] ?? 'Too many requests'}');
      throw RateLimitException('429 Too Many Requests');
    } else if (response.statusCode == 401) {
      // log.d('❌ 401 Unauthorized - Token might be expired or invalid');
      // log.d('Error response: ${data['message'] ?? 'Token expired'}');
      // Бросаем типизированное исключение для перехвата в _retryRequest.
      // Для auth-эндпоинтов (skipTokenRefresh: true) оно пробрасывается сразу,
      // без попытки обновить токен.
      throw TokenExpiredException(data['message'] ?? 'Неверные учетные данные');
    } else if (response.statusCode == 423) {
      // 423 = email не подтверждён (email_not_verified) или аккаунт заблокирован (account_locked).
      // Не бросаем исключение — возвращаем тело ответа, чтобы BLoC обработал
      // success:false и показал корректное сообщение пользователю.
      return data;
    } else if (response.statusCode == 422) {
      // Validation error - return response with errors
      // log.d('❌ 422 Validation Error');
      // log.d('Full error response: ${jsonEncode(data)}');
      if (data['errors'] is Map) {
        // log.d('\n📋 Detailed validation errors:');
        (data['errors'] as Map).forEach((key, value) {
          // log.d('  ❌ $key: $value');
          if (key == 'attributes' && value is List) {
            // log.d('     ^ ATTRIBUTES error! Check field structure');
          }
        });
      }
      // Don't throw exception, let calling code handle it
      return data;
    } else if (response.statusCode == 500) {
      // log.d('❌ 500 Server Error');
      // log.d('Error message: ${data['message'] ?? 'Server error'}');
      throw Exception(data['message'] ?? 'Ошибка сервера');
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      // 4xx ошибки (404, 400, 403, и т.д.) - выбрасываем исключение
      // Не возвращаем data, потому что это ошибка клиента
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

  static Future<List<Attribute>> getAdvertCreationAttributes({
    required int categoryId,
    String? token,
  }) async {
    try {
      final response = await getWithQuery('/adverts/create', {
        'category_id': categoryId,
      }, token: token);

      // log.d();
      // log.d('   response type: ${response.runtimeType}');
      // log.d('   data type: ${response['data']?.runtimeType}');

      // API возвращает: {"success":true,"data":[{"type":{...},"attributes":[...]}]}
      // data - это List с одним элементом
      final dataNode = response['data'];

      List<dynamic>? attributesJson;

      if (dataNode is List && dataNode.isNotEmpty) {
        // data это List - берём первый элемент
        final firstItem = dataNode[0] as Map<String, dynamic>?;
        attributesJson = firstItem?['attributes'] as List<dynamic>?;
        // log.d();
      } else if (dataNode is Map<String, dynamic>) {
        // data это Map - берём attributes напрямую
        attributesJson = dataNode['attributes'] as List<dynamic>?;
        // log.d();
      }

      if (attributesJson == null || attributesJson.isEmpty) {
        // log.d('   ❌ No attributes found in response');
        throw Exception('No attributes found in response');
      }

      // Парсим атрибуты с обработкой ошибок
      final attributes = <Attribute>[];
      for (int i = 0; i < attributesJson.length; i++) {
        try {
          final json = attributesJson[i];
          if (json is Map<String, dynamic>) {
            final attr = Attribute.fromJson(json);
            attributes.add(attr);
            // log.d();
          }
        } catch (e) {
          // log.d('   ⚠️ Failed to parse attribute at index $i: $e');
        }
      }

      // log.d('   ✅ Total parsed: ${attributes.length} attributes');
      return attributes;
    } catch (e) {
      // log.d('❌ getAdvertCreationAttributes error: $e');
      if (e.toString().contains('Token expired') && token != null) {
        // Попытка обновить токен и повторить запрос
        final newToken = await refreshToken(token);
        if (newToken != null) {
          return getAdvertCreationAttributes(
            categoryId: categoryId,
            token: newToken,
          );
        }
      }
      throw Exception('Failed to load advert creation attributes: $e');
    }
  }

  /// Получить список объявлений.
  static Future<AdvertsResponse> getAdverts({
    int? categoryId,
    int? catalogId,
    String? sort,
    Map<String, dynamic>? filters,
    int? page,
    int? limit,
    String? token,
    bool withAttributes = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      
      // 🔴 ВАЖНО: API НЕ ПРИНИМАЕТ ОБА ПАРАМЕТРА ОДНОВРЕМЕННО!
      // Если передан catalogId - используем его и игнорируем categoryId
      // Если передан только categoryId - используем его
      if (catalogId != null) {
        queryParams['catalog_id'] = catalogId;
        log.d('📦 API getAdverts - Using CATALOG_ID mode (catalogId=$catalogId)');
      } else if (categoryId != null) {
        queryParams['category_id'] = categoryId;
        log.d('📦 API getAdverts - Using CATEGORY_ID mode (categoryId=$categoryId)');
      } else {
        log.w('⚠️  API getAdverts: Neither catalogId nor categoryId provided!');
      }
      
      if (sort != null) queryParams['sort'] = sort;
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      // Добавляем фильтры
      if (filters != null && filters.isNotEmpty) {
        log.d('📦 API getAdverts - Processing filters:');
        filters.forEach((key, value) {
          // 🟢 СПЕЦИАЛЬНАЯ ОБРАБОТКА для filters[value_selected] (для атрибутов выбранных значений, ID < 1000)
          if (key == 'value_selected' && value is Map<String, dynamic>) {
            log.d('   📍 Processing value_selected:');
            // � FIX: API ожидает БЕЗ индексов, но поддерживает множественные значения через List!
            // getWithQuery() будет перевести List в: filters[value_selected][6]=40&filters[value_selected][6]=41
            value.forEach((attrId, attrValue) {
              if (attrValue is Set) {
                // 🟢 FIX: Преобразуем Set в List чтобы getWithQuery() создал несколько параметров
                final paramKey = 'filters[value_selected][$attrId]';
                final listValue = (attrValue as Set).toList().cast<String>();
                queryParams[paramKey] = listValue;
                log.d(
                    '      ✅ $paramKey = ${listValue.toList()} (as List for multiple params)');
              } else if (attrValue is List) {
                // Список значений
                final paramKey = 'filters[value_selected][$attrId]';
                queryParams[paramKey] = attrValue;
                log.d('      ✅ $paramKey = ${attrValue.toList()}');
              } else {
                // Простое значение
                final paramKey = 'filters[value_selected][$attrId]';
                queryParams[paramKey] = attrValue.toString();
                log.d('      ✅ $paramKey = ${attrValue.toString()}');
              }
            });
          } else if (key == 'values' && value is Map<String, dynamic>) {
            // 🟢 СПЕЦИАЛЬНАЯ ОБРАБОТКА для filters[values] (требуется API структура для диапазонов, ID >= 1000)
            // filters[values][attr_id][min], filters[values][attr_id][max] и т.д.
            value.forEach((attrId, attrValue) {
              if (attrValue is Map<String, dynamic>) {
                // Диапазоны: {min: 1, max: 5} - отправляем только если не пусто
                attrValue.forEach((rangeKey, rangeValue) {
                  // Строгая проверка: не отправляем пустые строки или null
                  if (rangeValue != null &&
                      rangeValue.toString().isNotEmpty &&
                      rangeValue.toString().trim().isNotEmpty) {
                    final paramKey = 'filters[values][$attrId][$rangeKey]';
                    queryParams[paramKey] = rangeValue.toString();
                    // log.d('  ✅ $paramKey = ${rangeValue.toString()}');
                  }
                });
              } else if (attrValue is Set) {
                // Множественный выбор
                final setList = attrValue.toList();
                if (setList.isNotEmpty) {
                  for (int i = 0; i < setList.length; i++) {
                    final paramKey = 'filters[values][$attrId][$i]';
                    queryParams[paramKey] = setList[i].toString();
                    // log.d('  ✅ $paramKey = ${setList[i].toString()}');
                  }
                }
              } else if (attrValue is List) {
                // Список значений
                if (attrValue.isNotEmpty) {
                  for (int i = 0; i < attrValue.length; i++) {
                    final paramKey = 'filters[values][$attrId][$i]';
                    queryParams[paramKey] = attrValue[i].toString();
                    // log.d('  ✅ $paramKey = ${attrValue[i].toString()}');
                  }
                }
              } else {
                // Простое значение (boolean и другие)
                final paramKey = 'filters[values][$attrId]';
                queryParams[paramKey] = attrValue.toString();
                // log.d('  ✅ $paramKey = ${attrValue.toString()}');
              }
            });
          } else if (value is Map<String, dynamic>) {
            // Вложенные Map (например {min: 1, max: 5}) - обработка для остальных структур
            value.forEach((subKey, subValue) {
              final paramKey = 'filters[$key][$subKey]';
              queryParams[paramKey] = subValue.toString();
              // log.d('  ✅ $paramKey = ${subValue.toString()}');
            });
          } else if (value is Set) {
            // Множественный выбор (Set<String>)
            // ⚠️ ВАЖНО: создаём РАЗНЫЕ ключи для каждого элемента!
            final setList = value.toList();
            if (setList.isNotEmpty) {
              for (int i = 0; i < setList.length; i++) {
                final paramKey = 'filters[$key][$i]';
                queryParams[paramKey] = setList[i].toString();
                // log.d('  ✅ $paramKey = ${setList[i].toString()}');
              }
            }
          } else if (value is List) {
            // Список значений
            // ⚠️ ВАЖНО: создаём РАЗНЫЕ ключи для каждого элемента!
            if (value.isNotEmpty) {
              for (int i = 0; i < value.length; i++) {
                final paramKey = 'filters[$key][$i]';
                queryParams[paramKey] = value[i].toString();
                // log.d('  ✅ $paramKey = ${value[i].toString()}');
              }
            }
          } else {
            // Простые значения (строки, числа)
            final paramKey = 'filters[$key]';
            queryParams[paramKey] = value.toString();
            // log.d('  ✅ $paramKey = ${value.toString()}');
          }
        });
      }

      // log.d('📋 Query Parameters:');
      queryParams.forEach((key, value) {
        // log.d('  📋 $key: $value');
      });

      // 🟢 ТЕСТИРОВАНИЕ: Сначала пытаемся БЕЗ параметра with=attributes
      // так как он может блокировать фильтры
      // queryParams['with'] = 'attributes';

      // 🟢 Добавляем параметр для получения атрибутов если нужно
      // (используется в fallback режиме для client-side фильтрации)
      if (withAttributes) {
        // Попробуем оба варианта параметра получения атрибутов
        queryParams['include'] = 'attributes'; // Вариант 1: include
        // queryParams['with'] = 'attributes'; // Вариант 2: with
      }

      // log.d('\n🔗 FULL REQUEST URL:');
      // log.d(
      //   '   GET /adverts?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&')}',
      // );
      // log.d('');

      final response = await getWithQuery(
        '/adverts',
        queryParams,
        token: token,
      );

      // DEBUG: Show filters being sent to server
      if (filters != null && filters.isNotEmpty) {
        // log.d('DEBUG: Filters sent = ' + filters.toString());
      }

      // 🔍 DEBUG: Логируем ответ для диагностики
      log.i('📋 API getAdverts() response keys: ${response.keys.toList()}');
      if (response.containsKey('data')) {
        log.i('   - data type: ${response['data'].runtimeType}');
        if (response['data'] is List) {
          log.i('   - data length: ${(response['data'] as List).length}');
        }
      } else {
        log.w('⚠️  ВНИМАНИЕ: API response для adverts НЕ содержит поле "data"!');
        log.w('   - Полный ответ: $response');
      }

      // DEBUG: Check how many results came back
      if (response is Map && response['data'] is List) {
        final count = (response['data'] as List).length;
        // log.d('DEBUG: API returned ' + count.toString() + ' listings');
      }

      return AdvertsResponse.fromJson(response);
    } catch (e, stackTrace) {
      log.e(
        '❌ ОШИБКА при загрузке объявлений: $e\n'
        '   - catalogId: $catalogId\n'
        '   - page: $page\n'
        '   - limit: $limit',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load adverts: $e');
    }
  }

  /// Получить одно объявление по ID.
  static Future<Advert> getAdvert(int id, {String? token}) async {
    try {
      // Пытаемся получить полный ответ с атрибутами и всеми полями
      final response = await getWithQuery('/adverts/$id', {
        'with': 'attributes,user', // Запрашиваем полные данные с атрибутами и пользователем
      }, token: token);
      final data = response['data'];
      
      // 🔍 DEBUG: Логируем ВСЕ данные из API
      log.d('\n═══════════════════════════════════════════════════════');
      log.d('🔔 API getAdvert($id) ПОЛНЫЙ ОТВЕТ:');
      if (data is Map<String, dynamic>) {
        log.d('📌 Тип: MAP');
        log.d('   - id: ${data['id']}');
        log.d('   - name: ${data['name'] ?? "EMPTY"}');
        log.d('   - price: ${data['price'] ?? "EMPTY"}');
        log.d('   - is_bargain: ${data['is_bargain'] ?? false}');
        log.d('   - description: ${(data['description'] as String?)?.isNotEmpty ?? false ? "✅" : "❌ EMPTY"}');
        log.d('   - address: ${data['address'] ?? "EMPTY"}');
        
        // Проверяем характеристики
        final attrs = data['attributes'];
        if (attrs is Map || attrs is List) {
          log.d('   - attributes: type=${attrs.runtimeType}, items=${attrs is Map ? attrs.length : (attrs as List).length}');
        } else {
          log.d('   - attributes: ${attrs ?? "NULL"}');
        }
        
        // Проверяем информацию о пользователе
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) {
          log.d('   - user.id: ${user['id'] ?? "EMPTY"}');
          log.d('   - user.name: ${user['name'] ?? "EMPTY"}');
          log.d('   - user.avatar: ${user['avatar'] ?? "EMPTY"}');
          log.d('   - user.created_at: ${user['created_at'] ?? "EMPTY"}');
        } else {
          log.d('   - user: ❌ NULL');
        }
      } else if (data is List && data.isNotEmpty) {
        final firstItem = data[0] as Map<String, dynamic>;
        log.d('📌 Тип: LIST[0]');
        log.d('   - id: ${firstItem['id']}');
        log.d('   - name: ${firstItem['name'] ?? "EMPTY"}');
        log.d('   - description: ${(firstItem['description'] as String?)?.isNotEmpty ?? false ? "✅" : "❌ EMPTY"}');
        final user = firstItem['user'] as Map<String, dynamic>?;
        if (user != null) {
          log.d('   - user.name: ${user['name'] ?? "EMPTY"}');
        } else {
          log.d('   - user: ❌ NULL');
        }
      } else {
        log.d('⚠️  STATUS: UNKNOWN TYPE or EMPTY');
      }
      log.d('═══════════════════════════════════════════════════════\n');
      
      if (data is List) {
        return Advert.fromJson(data[0] as Map<String, dynamic>);
      } else {
        return Advert.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      log.e('❌ getAdvert($id) ERROR: $e');
      throw Exception('Failed to load advert: $e');
    }
  }

  /// Получить атрибуты объявления (нужно запросить отдельно, т.к. API не включает их в список)
  static Future<Advert?> getAdvertWithAttributes(
    int id, {
    String? token,
  }) async {
    try {
      final response = await getWithQuery('/adverts/$id', {
        'with': 'attributes',
      }, token: token);
      final data = response['data'];
      if (data is List && data.isNotEmpty) {
        return Advert.fromJson(data[0] as Map<String, dynamic>);
      } else if (data is Map<String, dynamic>) {
        return Advert.fromJson(data);
      }
      return null;
    } catch (e) {
      // На ошибку просто возвращаем null и объявление останется БЕЗ атрибутов
      log.d('⚠️  Failed to load attributes for advert $id: $e');
      return null;
    }
  }

  /// Загрузить атрибуты для нескольких объявлений параллельно
  static Future<Map<int, Advert>> getAdvertsWithAttributes(
    List<int> advertIds, {
    String? token,
  }) async {
    final results = <int, Advert>{};

    // Загружаем максимум 5 одновременно, чтобы не перегружать API
    const batchSize = 5;
    for (int i = 0; i < advertIds.length; i += batchSize) {
      final batch = advertIds.sublist(
        i,
        (i + batchSize > advertIds.length) ? advertIds.length : i + batchSize,
      );

      final futures = batch.map(
        (id) => getAdvertWithAttributes(id, token: token),
      );
      final adverts = await Future.wait(futures);

      for (int j = 0; j < batch.length; j++) {
        final id = batch[j];
        final advert = adverts[j];
        if (advert != null) {
          results[id] = advert;
        }
      }
    }

    return results;
  }

  /// Получить все каталоги.
  static Future<catalog_models.CatalogsResponse> getCatalogs({String? token}) async {
    try {
      final response = await get('/content/catalogs', token: token);
      
      // 🔍 DEBUG: Логируем сырой ответ для диагностики
      log.i('📦 API getCatalogs() response keys: ${response.keys.toList()}');
      if (response.containsKey('data')) {
        log.i('   - data type: ${response['data'].runtimeType}');
        if (response['data'] is List) {
          log.i('   - data length: ${(response['data'] as List).length}');
        }
      } else {
        log.w('⚠️  ВНИМАНИЕ: API response НЕ содержит поле "data"!');
        log.w('   - Полный ответ: $response');
      }
      
      return catalog_models.CatalogsResponse.fromJson(response);
    } catch (e, stackTrace) {
      log.e(
        '❌ ОШИБКА при загрузке каталогов: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load catalogs: $e');
    }
  }

  /// Получить каталог с категориями по ID.
  static Future<catalog_models.CatalogWithCategories> getCatalog(
    int catalogId, {
    String? token,
  }) async {
    try {
      final response = await get('/content/catalogs/$catalogId', token: token);

      // Проверяем наличие data и что это не null
      if (response['data'] == null || response['data'] is! List) {
        throw Exception('Invalid catalog response: data is null or not a list');
      }

      final dataList = response['data'] as List<dynamic>;
      if (dataList.isEmpty) {
        throw Exception('Catalog not found');
      }

      return catalog_models.CatalogWithCategories.fromJson(
        dataList[0] as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to load catalog: $e');
    }
  }

  /// Получить категорию по ID.
  static Future<catalog_models.Category> getCategory(int categoryId, {String? token}) async {
    try {
      final response = await get(
        '/content/categories/$categoryId',
        token: token,
      );

      // Проверяем наличие data и что это не null
      if (response['data'] == null || response['data'] is! List) {
        throw Exception(
          'Invalid category response: data is null or not a list',
        );
      }

      final dataList = response['data'] as List<dynamic>;
      if (dataList.isEmpty) {
        throw Exception('Category not found');
      }

      return catalog_models.Category.fromJson(dataList[0] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load category: $e');
    }
  }

  /// Поиск категорий.
  static Future<catalog_models.CategoriesResponse> searchCategories({
    required int catalogId,
    required String query,
    String? token,
  }) async {
    try {
      final response = await getWithQuery('/content/categories/search', {
        'catalog_id': catalogId,
        'q': query,
      }, token: token);
      return catalog_models.CategoriesResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to search categories: $e');
    }
  }

  /// Получить фильтры для категории.
  static Future<MetaFiltersResponse> getMetaFilters({
    int? categoryId,
    int? catalogId,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;

      final response = await getWithQuery(
        '/meta/filters',
        queryParams,
        token: token,
      );
      // API returns { "success": true, "data": {"sort": [...], "filters": [...]} }
      // Extract the data object which contains sort and filters
      final data = response['data'] ?? response;
      // log.d('📊 Full filter JSON keys: ${data.keys.toList()}');
      if (data['filters'] is List) {
        final filtersList = data['filters'] as List;
        // log.d('📊 Filters count: ${filtersList.length}');
        for (int i = 0; i < filtersList.length; i++) {
          // log.d('  [$i] ID=${filtersList[i]['id']}, Title=${filtersList[i]['title']}, Values=${filtersList[i]['values']?.length ?? 0}');
          // log.d('       is_title_hidden=${filtersList[i]['is_title_hidden']}, is_special_design=${filtersList[i]['is_special_design']}');
        }
        // Сканируем все фильтры на предмет "Вам предложат цену"
        // log.d('🔍 Searching for "Вам предложат цену" filter...');
        bool found = false;
        for (final filter in filtersList) {
          final title = filter['title']?.toString() ?? '';
          if (title.contains('предложат') ||
              title.contains('цену') ||
              title.contains('offer') ||
              title.contains('price')) {
            // log.d('   ✅ Found possible match: ID=${filter['id']}, Title=$title');
            found = true;
          }
        }
        if (!found) {
          // log.d('   ❌ "Вам предложат цену" filter NOT found in API response!');
          // log.d('   NOTE: This filter is REQUIRED but not returned by API');
          // log.d('   It will be added programmatically in _loadAttributes()');
        }
      }
      try {
        // API returns: {"success":true,"data":{"sort":[...],"filters":[...]}}
        // data already contains {"sort": [...], "filters": [...]}
        // So we pass it directly to fromJson
        return MetaFiltersResponse.fromJson(data);
      } catch (parseError) {
        // log.d('🔴 ERROR parsing MetaFiltersResponse:');
        // log.d('   Error: $parseError');
        // log.d('   Data keys: ${data.keys}');
        rethrow;
      }
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        // Попытка обновить токен и повторить запрос
        final newToken = await refreshToken(token);
        if (newToken != null) {
          return getMetaFilters(
            categoryId: categoryId,
            catalogId: catalogId,
            token: newToken,
          );
        }
      }
      throw Exception('Failed to load meta filters: $e');
    }
  }

  /// Создать объявление.
  static Future<Map<String, dynamic>> createAdvert(
    CreateAdvertRequest request, {
    String? token,
  }) async {
    try {
      final json = request.toJson();
      // log.d('\n🚀 SENDING TO API: POST /adverts');
      // log.d('Full JSON:');
      // log.d(json);
      if (json['attributes'] != null) {
        // log.d('\nAttributes structure:');
        // log.d('  - value_selected: ${json['attributes']['value_selected']}');
        // log.d('  - values keys: ${json['attributes']['values']?.keys.toList()}');
        if (json['attributes']['values'] != null) {
          // log.d('  - values[1048]: ${json['attributes']['values']['1048']} (Type: ${json['attributes']['values']['1048'].runtimeType})');
          // log.d('  - values[1127]: ${json['attributes']['values']['1127']}');
          // log.d('  - values[1040]: ${json['attributes']['values']['1040']}');
        }
      }

      final response = await post('/adverts', json, token: token);
      return response;
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        // Попытка обновить токен и повторить запрос
        final newToken = await refreshToken(token);
        if (newToken != null) {
          return createAdvert(request, token: newToken);
        }
      }
      throw Exception('Failed to create advert: $e');
    }
  }

  /// Обновить объявление.
  static Future<Map<String, dynamic>> updateAdvert(
    int advertId,
    CreateAdvertRequest request, {
    String? token,
  }) async {
    try {
      final json = request.toJson();
      // log.d('\n🔄 SENDING TO API: PUT /adverts/$advertId');
      // log.d('Full JSON:');
      // log.d(json);
      if (json['attributes'] != null) {
        // log.d('\nAttributes structure:');
        // log.d('  - value_selected: ${json['attributes']['value_selected']}');
        // log.d('  - values keys: ${json['attributes']['values']?.keys.toList()}');
      }

      final response = await put('/adverts/$advertId', json, token: token);
      return response;
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        // Попытка обновить токен и повторить запрос
        final newToken = await refreshToken(token);
        if (newToken != null) {
          return updateAdvert(advertId, request, token: newToken);
        }
      }
      throw Exception('Failed to update advert: $e');
    }
  }

  /// Обновляет access_token используя refresh_token согласно API документации v1.4+
  ///
  /// Параметры (согласно POST /auth/refresh-token):
  /// - device_name: String (обязателен) — название устройства
  /// - app_version: String (опционален) — версия приложения из pubspec.yaml
  ///
  /// Возвращает новый access_token или null если refresh_token истёк/невалиден.
  ///
  /// Обновления (согласно последней документации):
  /// - Обрабатывает refresh_expires_in для проактивного обновления refresh_token
  /// - Сохраняет оба время истечения: token_expires_at и refresh_token_expires_at
  /// - Динамически читает device_name и app_version
  /// - 401/403 → null (нужна повторная авторизация)
  ///
  /// КРИТИЧНО: Метод ИГНОРИРУЕТ параметр currentToken и используем ТОЛЬКО refresh_token из Hive.
  /// Передача access_token вместо refresh_token приведет к 401 от сервера!
  static Future<String?> refreshToken(String currentToken) async {
    try {
      // POST /auth/refresh-token  (документация API v1.4+)
      // Authorization: Bearer {refresh_token}  ← refresh_token в заголовке
      // Body: {"device_name": "...", "app_version": "..."}
      //
      // Ответ 200: {
      //   "success": true,
      //   "access_token": "...",
      //   "refresh_token": "...",     ← ротируется при каждом refresh!
      //   "token_type": "Bearer",
      //   "expires_in": 900,           ← access_token истекает в 900 сек
      //   "refresh_expires_in": 1209600 ← refresh_token истекает в 1209600 сек (14 дней)
      // }
      // Ответ 401: "Вы не авторизованы" → нужен полный login
      // Ответ 403: "Неверный токен" → нужен полный login

      // ИСПРАВЛЕНИЕ: Используем ТОЛЬКО refresh_token из Hive, никогда не используем currentToken
      final refreshTokenValue =
          HiveService.getUserData('refresh_token') as String?;
      
      // Если refresh_token не найден - это критическая ошибка
      if (refreshTokenValue == null || refreshTokenValue.isEmpty) {
        log.d(
          '❌ refreshToken: refresh_token не найден в Hive, невозможно обновить токен',
        );
        return null;
      }

      final headers = {...defaultHeaders};
      // Передаём REFRESH_TOKEN (не access_token) как Bearer в Authorization
      headers['Authorization'] = 'Bearer $refreshTokenValue';

      // ОБНОВЛЕНО: Получаем device_name и app_version динамически
      final deviceName = await _getDeviceName();
      final appVersion = _getAppVersion(); // из pubspec.yaml: 1.0.0

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh-token'),
            headers: headers,
            // device_name обязателен согласно API документации — API отклонит запрос без него
            // app_version опционален, но рекомендуется отправлять для аналитики сервера
            body: jsonEncode({
              'device_name': deviceName,
              'app_version': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 15));

      // 401 = токен истёк, 403 = токен невалиден.
      // Оба случая означают что нужна повторная авторизация (нет автоматического рефреша).
      // TokenService._doRefresh() увидит null и вызовет _notifyTokenExpired().
      if (response.statusCode == 401 || response.statusCode == 403) {
        // log.d(
        //   '🔒 refreshToken: токен истёк/невалиден (${response.statusCode}): ${response.body}',
        // );
        return null;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // log.d(
        //   '❌ refreshToken: сервер вернул ${response.statusCode}: ${response.body}',
        // );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Проверяем флаг success
      if (data['success'] != true) {
        // log.d('❌ refreshToken: success=false: ${data['message']}');
        return null;
      }

      // Сохраняем новый access_token
      final newAccessToken = data['access_token'] as String?;
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await HiveService.saveUserData('token', newAccessToken);
        log.d(
          '✅ refreshToken: новый access_token сохранён: ${newAccessToken.substring(0, newAccessToken.length.clamp(0, 20))}...',
        );
      } else {
        log.d('❌ refreshToken: access_token не найден или пуст в ответе: $data');
        return null;
      }

      // API v1.4+: обновлённый refresh_token ротируется при каждом refresh
      // Без сохранения следующее обновление завершится 401 (старый refresh_token истёк).
      final newRefreshToken = data['refresh_token'] as String?;
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await HiveService.saveUserData('refresh_token', newRefreshToken);
        log.d('✅ refreshToken: новый refresh_token сохранён (ротация токена)');
      } else {
        log.d('❌ refreshToken: refresh_token не найден или пуст в ответе');
        return null;
      }

      // ОБНОВЛЕНО: Сохраняем время истечения access_token для TokenService
      // Sanctum opaque токены (формат "153|abc...") НЕ являются JWT —
      // нельзя декодировать поле exp. Используем expires_in из ответа сервера.
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 900;
      final expiresAtMs = DateTime.now()
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch;
      await HiveService.saveUserData('token_expires_at', expiresAtMs);
      log.d(
        '✅ refreshToken: access_token expires_in=$expiresIn сек, истекает в '
        '${DateTime.fromMillisecondsSinceEpoch(expiresAtMs).toLocal()}',
      );

      // ОБНОВЛЕНО: Сохраняем время истечения refresh_token для проактивного обновления
      // Если refresh_token истечет, пользователь не сможет обновить access_token
      // Поэтому обновляем refresh_token за 24 часа до его истечения (при необходимости)
      final refreshExpiresIn =
          (data['refresh_expires_in'] as num?)?.toInt() ?? 1209600;
      final refreshExpiresAtMs = DateTime.now()
          .add(Duration(seconds: refreshExpiresIn))
          .millisecondsSinceEpoch;
      await HiveService.saveUserData(
        'refresh_token_expires_at',
        refreshExpiresAtMs,
      );
      log.d(
        '✅ refreshToken: refresh_token expires_in=$refreshExpiresIn сек (14 дней), '
        'истекает в ${DateTime.fromMillisecondsSinceEpoch(refreshExpiresAtMs).toLocal()}',
      );

      // КРИТИЧНО: Перед возвратом проверяем что токен действительно сохранен в Hive
      final savedToken = HiveService.getUserData('token') as String?;
      if (savedToken == null || savedToken.isEmpty) {
        log.d('❌ refreshToken: КРИТИЧЕСКАЯ ОШИБКА - токен не был сохранен в Hive!');
        return null;
      }
      
      log.d('✅ refreshToken: токен успешно сохранен и готов к возврату');
      return newAccessToken;
    } catch (e) {
      // log.d('❌ refreshToken exception: $e');
      return null;
    }
  }

  /// Получает название устройства для отправки на сервер
  /// При необходимости можно использовать device_info_plus для получения реального имени
  static Future<String> _getDeviceName() async {
    try {
      // Можно расширить с использованием device_info_plus если нужно реальное имя устройства
      // Для теперь используем фиксированное значение
      return 'Lidle Mobile App';
    } catch (_) {
      return 'Unknown Device';
    }
  }

  /// Получает версию приложения из pubspec.yaml (формат: 1.0.0)
  static String _getAppVersion() {
    // В реальном приложении используйте package_info_plus для получения версии во время выполнения
    // Для теперь используем фиксированное значение из pubspec.yaml
    return '1.0.0'; // version: 1.0.0+1 из pubspec.yaml
  }

  /// Получить главную страницу с каталогами и объявлениями
  static Future<Map<String, dynamic>> getMainContent({String? token}) async {
    try {
      return await get('/content/main', token: token);
    } catch (e) {
      throw Exception('Failed to load main content: $e');
    }
  }

  /// Сохранить просмотр объявления
  static Future<void> saveAdvertView(int advertId, {String? token}) async {
    try {
      await post('/adverts/$advertId/view', {}, token: token);
    } catch (e) {
      // log.d('Failed to save advert view: $e');
      // Не пробрасываем ошибку, так как это некритично
    }
  }

  /// Сохранить поделиться объявлением
  static Future<void> shareAdvert(int advertId, {String? token}) async {
    try {
      await post('/adverts/$advertId/share', {}, token: token);
    } catch (e) {
      // log.d('Failed to share advert: $e');
      // Не пробрасываем ошибка
    }
  }

  /// Загрузить файл через multipart/form-data
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint, {
    required String filePath,
    required String fieldName,
    String? token,
  }) async {
    try {
      final headers = {'X-App-Client': 'mobile'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // log.d('═══════════════════════════════════════════════════════');
      // log.d('📤 MULTIPART UPLOAD REQUEST');
      // log.d('URL: $baseUrl$endpoint');
      // log.d('Field name: $fieldName');
      // log.d('File: $filePath');
      // log.d('Token provided: ${token != null}');
      // log.d('═══════════════════════════════════════════════════════');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      throw Exception('Ошибка загрузки файла: $e');
    }
  }

  /// Загрузить/обновить изображения для объявления
  ///
  /// Поддерживает три операции согласно документации API:
  /// 1. Загрузка новых изображений (List<String> imagePaths)
  /// 2. Сохранение существующих изображений (List<String> existingImages)
  /// 3. Удаление изображений (List<String> deleteImages)
  ///
  /// ОГРАНИЧЕНИЯ по API:
  /// - Обязательно должен быть передан хотя бы один из параметров: imagePaths или deleteImages
  /// - НЕЛЬЗЯ одновременно загружать новые и удалять: либо images, либо delete_images
  /// - Порядок изображений сохраняется как в параметре
  /// - Существующие изображения могут быть переданы как строки (имена файлов)
  static Future<Map<String, dynamic>> uploadAdvertImages(
    int advertId,
    List<String> imagePaths, {
    required String token,
    List<String>? existingImages,
    List<String>? deleteImages,
    Function(int uploaded, int total)? onProgress,
  }) async {
    try {
      // Валидация: должен быть хотя бы один параметр
      final hasImagesToUpload =
          imagePaths.isNotEmpty || (existingImages?.isNotEmpty ?? false);
      final hasImagesToDelete = deleteImages?.isNotEmpty ?? false;

      if (!hasImagesToUpload && !hasImagesToDelete) {
        throw Exception(
          'Ошибка: нужно передать хотя бы один параметр (images или delete_images)',
        );
      }

      // Валидация: нельзя одновременно загружать и удалять
      if (hasImagesToUpload && hasImagesToDelete) {
        throw Exception(
          'Ошибка: нельзя одновременно загружать и удалять изображения. '
          'Выберите либо загрузку (images), либо удаление (delete_images)',
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/adverts/$advertId/images'),
      );

      // Добавить заголовки авторизации
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        ...defaultHeaders,
      });

      // Добавить новые загруженные файлы
      int imageIndex = 0;
      for (final filePath in imagePaths) {
        // log.d('📎 Adding image $imageIndex: $filePath');
        final file = File(filePath);

        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('images[$imageIndex]', filePath),
          );
          imageIndex++;
        } else {
          // log.d('⚠️ File not found: $filePath');
        }
      }

      // Добавить существующие изображения (для сохранения текущих и/или изменения порядка)
      if (existingImages != null && existingImages.isNotEmpty) {
        for (int i = 0; i < existingImages.length; i++) {
          final existingFileName = existingImages[i];
          request.fields['images[${imageIndex + i}]'] = existingFileName;
          // log.d('📸 Preserving existing image: $existingFileName');
        }
      }

      // Добавить изображения для удаления (если требуется)
      if (deleteImages != null && deleteImages.isNotEmpty) {
        for (int i = 0; i < deleteImages.length; i++) {
          request.fields['delete_images[$i]'] = deleteImages[i];
          // log.d('🗑️ Marking for deletion: ${deleteImages[i]}');
        }
      }

      // Логирование запроса
      // log.d('════════════════════════════════════════════════════');
      // log.d('📤 MULTIPART REQUEST to /adverts/$advertId/images');
      // log.d('   Mode: ${deleteImages != null ? 'DELETE' : 'UPLOAD'}');
      // log.d('   New files: ${imagePaths.length}');
      if (existingImages != null && existingImages.isNotEmpty) {
        // log.d('   Existing: ${existingImages.length}');
      }
      if (deleteImages != null && deleteImages.isNotEmpty) {
        // log.d('   To delete: ${deleteImages.length}');
      }
      // log.d('════════════════════════════════════════════════════');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // log.d('тЬЕ API Response status: ${response.statusCode}');
      // log.d('ЁЯУЛ Response body: ${response.body}');

      if (response.statusCode == 200) {
        // log.d('✅ Images operation completed successfully!');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        // Токен истёк - пытаемся обновить и повторить
        // log.d('⚠️ Token expired (401), attempting to refresh...');
        final newToken = await refreshToken(token);
        if (newToken != null) {
          // log.d('✅ Token refreshed, retrying upload...');
          return uploadAdvertImages(
            advertId,
            imagePaths,
            token: newToken,
            existingImages: existingImages,
            deleteImages: deleteImages,
            onProgress: onProgress,
          );
        }
        throw Exception('Токен истёк и обновление не удалось');
      } else if (response.statusCode == 404) {
        throw Exception('Объявление не найдено (ID: $advertId)');
      } else if (response.statusCode == 422) {
        // Ошибка валидации - обычно это означает попытку одновременно загружать и удалять
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] ?? 'Validation error';
        throw Exception('Ошибка валидации: $message');
      } else {
        throw Exception(
          'Ошибка при операции с изображениями: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // log.d('тЭМ Error with image operation: $e');
      rethrow;
    }
  }

  /// Получить список регионов
  /// Может работать с токеном или без (параллельно для анонимных пользователей)
  static Future<List<Map<String, dynamic>>> getRegions({String? token}) async {
    try {
      final headers = {...defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$baseUrl/addresses/regions');

      // log.d('═══════════════════════════════════════════════════════');
      // log.d('📥 GET REQUEST /addresses/regions');
      // log.d('URL: $uri');

      final response = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 30),
          ); // Увеличен timeout для регионов

      // log.d('✅ API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['data'] != null) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          return List<Map<String, dynamic>>.from(
            data.whereType<Map<String, dynamic>>(),
          );
        }
        return [];
      } else if (response.statusCode == 401 && token != null) {
        // Токен истёк, но это non-critical эндпоинт
        // Не пробуем refresh, просто возвращаем пустой список
        // Пользователь сможет повторить позже
        log.d(
          '⚠️ getRegions: 401 Unauthorized (token expired, skipping refresh)',
        );
        return [];
      } else {
        throw Exception('Failed to get regions: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Timeout при загрузке регионов (превышено 30 сек)');
    } catch (e) {
      // Логируем ошибку но возвращаем пустой список чтобы не сломать приложение
      log.d('⚠️ getRegions error: $e');
      return [];
    }
  }

  /// Вспомогательный метод для парсинга JSON на фоновом потоке.
  /// Используется compute() для больших ответов.
  static Map<String, dynamic> _parseJsonOnBackgroundThread(String jsonString) {
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Поиск адресов по запросу
  /// Возвращает список результатов поиска с ID region, city, street, building
  /// Note: API expects GET request with JSON body (unusual but required)
  static Future<List<Map<String, dynamic>>> searchAddresses(
    String query, {
    String? token,
    List<String>? types,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final headers = {...defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Build request body for GET request (API requires JSON body, not query params)
      final bodyMap = <String, dynamic>{'q': query};
      if (types != null && types.isNotEmpty) {
        bodyMap['types'] = types;
      }
      if (filters != null && filters.isNotEmpty) {
        bodyMap['filters'] = filters;
      }

      final uri = Uri.parse('$baseUrl/addresses/search');

      // log.d('═══════════════════════════════════════════════════════');
      // log.d('📥 GET REQUEST /addresses/search');
      // log.d('URL: $uri');
      // log.d('Token provided: ${token != null}');
      if (token != null) {
        // log.d('Token preview: ${token.substring(0, 30)}...');
      }
      // log.d('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // log.d('  $key: Bearer [HIDDEN]');
        } else {
          // log.d('  $key: $value');
        }
      });
      // log.d('Body: ${jsonEncode(bodyMap)}');

      // Use http.Request to send GET with JSON body (unusual but API requires it)
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      request.body = jsonEncode(bodyMap);

      final streamResponse = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final response = await http.Response.fromStream(streamResponse);

      // log.d('✅ API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true || jsonResponse['data'] != null) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          return List<Map<String, dynamic>>.from(
            data.whereType<Map<String, dynamic>>(),
          );
        }
        return [];
      } else {
        throw Exception('Failed to search addresses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching addresses: $e');
    }
  }

  /// Получить фильтры для листинга объявлений
  static Future<Map<String, dynamic>> getListingsFilterAttributes({
    required int categoryId,
    String? token,
  }) async {
    try {
      log.d('🔵 [ApiService.getListingsFilterAttributes] START - categoryId=$categoryId, token=${token != null ? 'YES' : 'NO'}');
      
      final response = await getWithQuery('/adverts/create', {
        'category_id': categoryId,
      }, token: token);

      log.d('🔵 [ApiService] Raw response: $response');
      log.d('🔵 [ApiService] Response data type: ${response['data'].runtimeType}');

      // Если требуется токен и он истёк, обновить и повторить
      if (response['message'] != null &&
          response['message'].toString().contains('Token expired') &&
          token != null) {
        final newToken = await refreshToken(token);
        if (newToken != null) {
          return getListingsFilterAttributes(
            categoryId: categoryId,
            token: newToken,
          );
        }
      }

      // Структура ответа: {"data": [{"type": {...}, "attributes": [...]}]}
      // Берём attributes из первого элемента
      List<dynamic> attributes = [];
      if (response['data'] is List) {
        final dataList = response['data'] as List<dynamic>;
        log.d('🔵 [ApiService] dataList length: ${dataList.length}');
        if (dataList.isNotEmpty && dataList[0] is Map) {
          final firstItem = dataList[0] as Map<String, dynamic>;
          log.d('🔵 [ApiService] firstItem keys: ${firstItem.keys.toList()}');
          attributes = firstItem['attributes'] as List<dynamic>? ?? [];
          log.d('🔵 [ApiService] Extracted ${attributes.length} attributes');
        } else {
          log.d('🔵 [ApiService] dataList is empty or first item is not Map');
        }
      } else {
        log.d('🔵 [ApiService] response[data] is not List, it is: ${response['data'].runtimeType}');
      }

      // Вернуть весь ответ
      log.d('🔵 [ApiService.getListingsFilterAttributes] SUCCESS - returning ${attributes.length} attributes');
      return {
        'success': true,
        'data': attributes,
        'message': response['message'],
      };
    } catch (e) {
      log.d('🔴 [ApiService.getListingsFilterAttributes] ERROR: $e');
      log.d('🔴 [ApiService] Stack: ${StackTrace.current}');
      return {'success': false, 'data': [], 'message': e.toString()};
    }
  }

  /// 💰 Отправить предложение цены для объявления
  /// POST /v1/adverts/{id}/offer
  /// Параметры:
  /// - advertId: ID объявления
  /// - price: Предложенная цена (число)
  /// - message: Сообщение продавцу
  /// - token: Bearer токен пользователя
  static Future<Map<String, dynamic>> submitPriceOffer({
    required int advertId,
    required double price,
    required String message,
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      final body = {'price': price, 'message': message};

      final response = await post(
        '/adverts/$advertId/offer',
        body,
        token: effectiveToken,
      );

      // log.d('✅ Price offer sent successfully for advert $advertId');
      return response;
    } catch (e) {
      // log.d('❌ Error submitting price offer: $e');
      rethrow;
    }
  }

  /// 💵 Получить список предложений цены для объявления
  /// GET /v1/me/offers/received/{slug}/{id}
  /// Возвращает список предложений с информацией о пользователе
  /// 📥 Получить список предложений для конкретного объявления
  /// GET /v1/me/offers/received/{slug}/{id}
  /// Возвращает список предложений цены для конкретного объявления пользователя
  static Future<List<Map<String, dynamic>>> getPriceOffers({
    required int advertId,
    required String advertSlug,
    String? token,
    int page = 1,
    List<String> sort = const ['new'],
  }) async {
    try {
      log.d(
        '🔗 getPriceOffers() calling: /me/offers/received/$advertSlug/$advertId',
      );

      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      // Endpoint принимает параметры через query string (sort — опциональный)
      final queryParams = <String, dynamic>{'page': page};

      final response = await getWithQuery(
        '/me/offers/received/$advertSlug/$advertId',
        queryParams,
        token: effectiveToken,
      );

      log.d('📊 getPriceOffers() response:');
      log.d('   Keys: ${response.keys.toList()}');
      log.d('   Full response: $response');

      if (response['data'] is List) {
        final offers = List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map<String, dynamic>>(),
        );
        log.d('✅ getPriceOffers() returning ${offers.length} offers');
        return offers;
      }

      log.d('⚠️ getPriceOffers() data is not a List, returning empty');
      return [];
    } catch (e) {
      log.d('❌ Error getting price offers: $e');
      rethrow;
    }
  }

  /// 📤 Получить список МОЕ ОТПРАВЛЕННЫХ предложений цены
  /// GET /v1/me/offers
  /// Возвращает список предложений, которые пользователь отправил на объявления
  static Future<List<Map<String, dynamic>>> getMyOffers({
    String? token,
    int page = 1,
    List<String> sort = const ['new'],
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      final body = {'sort': sort, 'page': page};

      final response = await getWithBody(
        '/me/offers',
        body,
        token: effectiveToken,
      );

      // Возвращаем список предложений
      // Если нет предложений, API возвращает data: null вместо пустого массива
      if (response['data'] is List) {
        final offers = List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map<String, dynamic>>(),
        );

        // log.d('📊 getMyOffers() returned ${offers.length} offers');
        if (offers.isNotEmpty) {
          // log.d('   First offer structure:');
          // offers.first.forEach((key, value) {
          //   if (value is Map || value is List) {
          //     log.d('      $key: [object with keys]');
          //   } else {
          //     log.d('      $key: $value (${value.runtimeType})');
          //   }
          // });
        }

        return offers;
      } else if (response['data'] == null) {
        return [];
      }

      // Другие типы - значит ошибка структуры

      return [];
    } catch (e) {
      log.d('❌ Error in getMyOffers: $e');
      return [];
    }
  }

  /// 💵 Получить список объявлений с полученными предложениями
  /// GET /v1/me/offers/received - получает список объявлений где пользователь получил предложения
  static Future<List<Map<String, dynamic>>> getOffersReceivedList({
    String? token,
    int page = 1,
    List<String> sort = const ['new'],
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      final body = {'sort': sort, 'page': page};

      final response = await getWithBody(
        '/me/offers/received',
        body,
        token: effectiveToken,
      );

      // Возвращаем список объявлений с информацией о предложениях
      // API может вернуть data: null если нет объявлений
      if (response['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map<String, dynamic>>(),
        );
      } else if (response['data'] == null) {
        return [];
      }

      return [];
    } catch (e) {
      // log.d('❌ Error getting offers received list: $e');
      return [];
    }
  }

  /// 💵 Получить все полученные предложения со всех объявлений
  /// Комбинирует getOffersReceivedList + getPriceOffers для всех объявлений
  static Future<List<Map<String, dynamic>>> getAllReceivedOffers({
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      // Сначала получаем список объявлений с полученными предложениями
      final listingsWithOffers = await getOffersReceivedList(
        token: effectiveToken,
      );

      if (listingsWithOffers.isEmpty) {
        return [];
      }

      // Теперь для каждого объявления получаем список всех предложений
      List<Map<String, dynamic>> allOffers = [];

      for (final listing in listingsWithOffers) {
        final id = listing['id'];
        final slug = listing['slug'];

        if (id != null && slug != null) {
          final offers = await getPriceOffers(
            advertId: id as int,
            advertSlug: slug as String,
            token: effectiveToken,
          );
          allOffers.addAll(offers);
        }
      }

      return allOffers;
    } catch (e) {
      // log.d('❌ Error getting all received offers: $e');
      return [];
    }
  }

  /// � Обновить статус ПОЛУЧЕННОГО предложения
  /// PUT /v1/me/offers/received/{id}
  /// statusId: 2 = Цена принята, 3 = Отказ от цены
  static Future<Map<String, dynamic>> updateReceivedOfferStatus({
    required int offerId,
    required int statusId,
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      final body = {'offer_status_id': statusId};

      log.d(
        '🔄 Обновляем статус полученного предложения #$offerId на $statusId',
      );

      final response = await put(
        '/me/offers/received/$offerId',
        body,
        token: effectiveToken,
      );

      log.d('✅ updateReceivedOfferStatus response: $response');
      return response;
    } catch (e) {
      log.d('❌ Ошибка updateReceivedOfferStatus: $e');
      rethrow;
    }
  }

  /// �💰 Обновить статус полученного предложения цены
  /// DELETE /v1/me/offers/{id}
  /// Обновить статус ценового предложения которое я отправил
  /// Параметры:
  /// - offerId: ID предложения
  /// - statusId: ID статуса (2=Accepted, 3=Refused)
  /// - token: Bearer токен пользователя
  static Future<Map<String, dynamic>> updateOfferStatus({
    required int offerId,
    required int statusId,
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      final body = {'offer_status_id': statusId};

      log.d(
        '🔄 Обновляем статус своего предложения #$offerId на статус $statusId',
      );
      log.d('   Endpoint: /me/offers/$offerId');
      log.d('   Body: $body');
      log.d('   ℹ️  Это МОЕ предложение которое я отправил');

      final response = await delete(
        '/me/offers/$offerId',
        token: effectiveToken,
        body: body,
      );

      log.d('✅ API Response received:');
      log.d('   Response type: ${response.runtimeType}');
      log.d('   Response keys: ${response.keys.toList()}');
      log.d('   Full response: $response');

      // Пытаемся получить success field - может быть во вложенной структуре
      var success = response['success'];
      var message = response['message'];
      var data = response['data'];

      log.d('   success field: $success (type: ${success.runtimeType})');
      log.d(
        '   message field: $message (type: ${message?.runtimeType ?? "null"})',
      );
      log.d('   data field: $data (type: ${data?.runtimeType ?? "null"})');

      // Проверяем успешность - success может быть true или в другой структуре
      if (success == true) {
        log.d('   ✅ Статус успешно обновлен!');
        return response;
      } else if (success == false) {
        final errMsg = message ?? 'Неизвестная ошибка';
        log.d('   ❌ API вернул success=false');
        log.d('   Message: $errMsg');
        throw Exception(errMsg);
      } else {
        // success может быть null или отсутствовать
        log.d('   ⚠️ Поле success имеет неожиданное значение: $success');
        if (message != null) {
          log.d('   Message: $message');
          throw Exception(message);
        } else {
          log.d(
            '   Предположим что операция успешна (success не присутствует)',
          );
          return response;
        }
      }
    } catch (e) {
      log.d('❌ Ошибка при обновлении статуса предложения: $e');
      rethrow; // Используем rethrow вместо throw Exception для сохранения stacktrace
    }
  }

  /// 👤 Получить информацию о пользователе по ID
  /// GET /v1/users/{id}
  /// Возвращает профиль пользователя с контактной информацией
  static Future<Map<String, dynamic>> getUserProfile({
    required int userId,
    String? token,
  }) async {
    try {
      log.d('👤 Getting user profile for userId: $userId');

      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      final response = await get('/users/$userId', token: effectiveToken);

      log.d('📦 getUserProfile() response keys: ${response.keys.toList()}');

      if (response['data'] is List && (response['data'] as List).isNotEmpty) {
        final userData = (response['data'] as List)[0] as Map<String, dynamic>;
        log.d('✅ Got user profile for: ${userData['name']}');
        log.d('   Fields: name, created_at, avatar, contacts, qrCode');
        log.d(
          '   ⚠️ NOTE: /users/{id} endpoint does NOT include nickname field',
        );
        log.d('   According to docs/api/users_user_profile_report_adverts.md');
        log.d('   Using @name as fallback for display name');

        return userData;
      }

      log.d('⚠️ No data in user profile response');
      return {};
    } catch (e) {
      log.d('❌ Error getting user profile: $e');
      return {};
    }
  }

  /// 📞 Получить список телефонов пользователя по ID
  /// Извлекает поле contacts из профиля пользователя и парсит телефоны
  static Future<List<String>> getUserPhones({
    required int userId,
    String? token,
  }) async {
    try {
      log.d('📞 Getting user phones for userId: $userId');

      final userProfile = await getUserProfile(userId: userId, token: token);

      if (userProfile.isEmpty) {
        log.d('⚠️ User profile is empty');
        return [];
      }

      // Парсим contacts из профиля
      final contacts = userProfile['contacts'];
      if (contacts == null) {
        log.d('⚠️ No contacts found in user profile');
        return [];
      }

      final phoneNumbers = <String>[];

      // contacts может быть Map с разными типами контактов (phone_numbers, whatsapps, telegrams и т.д.)
      if (contacts is Map<String, dynamic>) {
        // Ищем phone_numbers поле
        final phoneField = contacts['phone_numbers'] ?? contacts['phones'];

        if (phoneField is List) {
          for (final phone in phoneField) {
            if (phone is Map<String, dynamic>) {
              // Если это объект с полями (например {id: 1, phone: "+79494565667"})
              final phoneValue =
                  phone['phone'] ?? phone['number'] ?? phone['value'];
              if (phoneValue != null && phoneValue.toString().isNotEmpty) {
                phoneNumbers.add(phoneValue.toString());
              }
            } else if (phone is String && phone.isNotEmpty) {
              // Если это просто строка с номером
              phoneNumbers.add(phone);
            }
          }
        } else if (phoneField is String && phoneField.isNotEmpty) {
          // Если это одиночный номер в виде строки
          phoneNumbers.add(phoneField);
        }

        // Если не нашли phone_numbers, пробуем другие поля contact'а
        if (phoneNumbers.isEmpty) {
          final allPhones = <String>[];
          contacts.forEach((key, value) {
            if (key.contains('phone') || key == 'phone') {
              if (value is List) {
                for (final phone in value) {
                  final phoneStr = phone is Map
                      ? (phone['phone'] ?? phone['number'] ?? phone['value'])
                      : phone;
                  if (phoneStr != null && phoneStr.toString().isNotEmpty) {
                    allPhones.add(phoneStr.toString());
                  }
                }
              } else if (value is String && value.isNotEmpty) {
                allPhones.add(value);
              }
            }
          });
          phoneNumbers.addAll(allPhones);
        }
      } else if (contacts is List) {
        // Если contacts это массив объектов с телефонами
        for (final contact in contacts) {
          if (contact is Map<String, dynamic>) {
            final phone =
                contact['phone'] ?? contact['number'] ?? contact['value'];
            if (phone != null && phone.toString().isNotEmpty) {
              phoneNumbers.add(phone.toString());
            }
          } else if (contact is String && contact.isNotEmpty) {
            phoneNumbers.add(contact);
          }
        }
      }

      // Удаляем дубликаты и пустые значения
      phoneNumbers.removeWhere((p) => p.isEmpty);
      final uniquePhones = phoneNumbers.toSet().toList();

      log.d('✅ Got ${uniquePhones.length} phone numbers for user $userId');
      uniquePhones.forEach((phone) => log.d('   📱 $phone'));

      return uniquePhones;
    } catch (e) {
      log.d('❌ Error getting user phones: $e');
      return [];
    }
  }

  /// 💬 Получить список всех чатов
  /// GET /v1/chats
  static Future<List<Map<String, dynamic>>> getChats({
    int page = 1,
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      // log.d('📥 Загружаем список чатов (страница $page)...');

      final response = await getWithQuery(
        '/chats',
        {'page': page.toString()},
        token: effectiveToken,
      );

      if (response['data'] != null && response['data'] is List) {
        final chats = List<Map<String, dynamic>>.from(response['data'] as List);
        // log.d('✅ Загружено чатов: ${chats.length}');
        return chats;
      }

      return [];
    } catch (e) {
      // log.d('❌ Ошибка загрузки чатов: $e');
      rethrow;
    }
  }

  /// 💬 Получить сообщения из конкретного чата
  /// GET /v1/chats/{chatId}/messages
  static Future<List<Map<String, dynamic>>> getChatMessages(
    int chatId, {
    int page = 1,
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      // log.d('📥 Загружаем сообщения чата #$chatId (страница $page)...');

      final response = await getWithQuery(
        '/chats/$chatId/messages',
        {'page': page.toString()},
        token: effectiveToken,
      );

      if (response['data'] != null && response['data'] is List) {
        final messages =
            List<Map<String, dynamic>>.from(response['data'] as List);
        // log.d('✅ Загружено сообщений: ${messages.length}');
        return messages;
      }

      return [];
    } catch (e) {
      // log.d('❌ Ошибка загрузки сообщений: $e');
      rethrow;
    }
  }

  /// 💬 Отправить сообщение в чат
  /// POST /v1/chats/{chatId}/messages
  static Future<Map<String, dynamic>> sendMessage(
    int chatId,
    String messageText, {
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      if (messageText.isEmpty) {
        throw Exception('Сообщение не может быть пустым');
      }

      log.d('📤 Отправляем сообщение в чат #$chatId...');

      final response = await post(
        '/chats/$chatId/messages',
        {'message': messageText},
        token: effectiveToken,
      );

      log.d('✅ Сообщение отправлено: $response');
      return response;
    } catch (e) {
      log.d('❌ Ошибка отправки сообщения: $e');
      rethrow;
    }
  }

  /// 💬 Начать новый чат с пользователем
  /// POST /v1/chats/start
  static Future<int?> startChat(
    int userId,
    String messageText, {
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      if (messageText.isEmpty) {
        throw Exception('Сообщение не может быть пустым');
      }

      log.d('💬 Начинаем чат с пользователем #$userId...');

      final response = await post(
        '/chats/start',
        {
          'user_id': userId,
          'message': messageText,
        },
        token: effectiveToken,
      );

      log.d('✅ Чат создан: $response');

      // Пытаемся получить ID чата из ответа
      if (response['data'] != null && response['data'] is List) {
        final data = (response['data'] as List).first as Map<String, dynamic>;
        return data['id'] as int?;
      }

      return null;
    } catch (e) {
      log.d('❌ Ошибка создания чата: $e');
      rethrow;
    }
  }

  /// 🗑️ Удалить чат
  /// DELETE /v1/chats/{chatId}
  static Future<bool> deleteChat(
    int chatId, {
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      log.d('🗑️ Удаляем чат #$chatId...');

      final response = await delete(
        '/chats/$chatId',
        token: effectiveToken,
      );

      log.d('✅ Ответ удаления чата: $response');
      return response['success'] == true || response['data'] != null;
    } catch (e) {
      log.d('❌ Ошибка удаления чата: $e');
      rethrow;
    }
  }

  /// ✅ Отметить сообщение как прочитанное
  /// POST /v1/chats/{chatId}/messages/{messageId}/read
  static Future<bool> markMessageAsRead(
    int chatId,
    int messageId, {
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      log.d('✅ Отмечаем сообщение #$messageId как прочитанное...');

      final response = await post(
        '/chats/$chatId/messages/$messageId/read',
        {},
        token: effectiveToken,
      );

      log.d('✅ Сообщение отмечено как прочитанное: $response');
      return response['success'] == true;
    } catch (e) {
      log.d('⚠️ Ошибка при отметке сообщения как прочитанного: $e');
      // Не выбрасываем исключение, так как это не критично
      return false;
    }
  }

  /// 🗑️ Удалить объявление из избранного
  /// DELETE /v1/me/wishlist/destroy/{advertId}
  /// Параметры:
  /// - advertId: ID объявления для удаления из избранного
  /// - token: Bearer токен пользователя
  static Future<Map<String, dynamic>> removeFromWishlist({
    required int advertId,
    String? token,
  }) async {
    try {
      final effectiveToken =
          token ?? (HiveService.getUserData('token') as String?);
      if (effectiveToken == null) {
        throw Exception('Требуется авторизация');
      }

      log.d('🗑️ Удаляем объявление #$advertId из избранного...');

      final response = await delete(
        '/me/wishlist/destroy/$advertId',
        token: effectiveToken,
      );

      log.d('✅ Ответ от API: $response');
      return response;
    } catch (e) {
      log.d('❌ Ошибка удаления из избранного: $e');
      rethrow;
    }
  }
}
