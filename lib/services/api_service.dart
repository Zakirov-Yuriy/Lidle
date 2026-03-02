import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:lidle/models/filter_models.dart'; // Import the new model
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/models/create_advert_model.dart';
import 'package:lidle/hive_service.dart';

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
  // ОПТИМИЗАЦИЯ: Базовый URL захардкодирован чтобы не использовать dotenv при инициализации
  // dotenv.load() отнимает ~900ms, а базовый URL не меняется
  static String get baseUrl => 'https://dev-api.lidle.io/v1';
  static const int _maxRetries = 4;
  static const int _retryDelayMs =
      1000; // Стартовая задержка перед retry (exponential backoff)
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    // Заголовки согласно официальной документации API Lidle
    'X-App-Client': 'mobile',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
    'Content-Type': 'application/json',
  };

  /// Защита от частых попыток refresh токена (debounce)
  /// Хранит timestamp последней попытки refresh
  static DateTime? _lastTokenRefreshAttempt;

  /// Минимальный интервал между попытками refresh (в секундах)
  static const int _tokenRefreshMinIntervalSeconds = 2;

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
    return _retryRequest(() => _getRequest(endpoint, token), endpoint);
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

      // print('═══════════════════════════════════════════════════════');
      // print('📥 GET REQUEST');
      // print('URL: $baseUrl$endpoint');
      // print('Token provided: ${effectiveToken != null}');
      if (effectiveToken != null) {
        // print('Token preview: ${effectiveToken.substring(0, 30)}...');
        // print('Token type: JWT');
      }
      // print('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // print('  $key: Bearer [HIDDEN]');
        } else {
          // print('  $key: $value');
        }
      });
      // print('═══════════════════════════════════════════════════════');

      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 10));

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
  }) async {
    return _retryRequest(() => _postRequest(endpoint, body, token), endpoint);
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

      // print('═══════════════════════════════════════════════════════');
      // print('📤 POST REQUEST');
      // print('URL: $baseUrl$endpoint');
      // print('Token provided: ${effectiveToken != null}');
      if (effectiveToken != null) {
        // print('Token preview: ${effectiveToken.substring(0, 30)}...');
        // print('Token type: JWT');
      }
      // print('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // print('  $key: Bearer [HIDDEN]');
        } else {
          // print('  $key: $value');
        }
      });
      // print('Body: $body');
      // print('═══════════════════════════════════════════════════════');

      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

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
      () => _getWithBodyRequest(endpoint, body, token),
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
      throw Exception('Неизвестная ошибка');
    }
  }

  /// Выполняет GET запрос с query параметрами с retry при 429.
  static Future<Map<String, dynamic>> getWithQuery(
    String endpoint,
    Map<String, dynamic> queryParams, {
    String? token,
  }) async {
    return _retryRequest(
      () => _getWithQueryRequest(endpoint, queryParams, token),
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

      // print('═══════════════════════════════════════════════════════');
      // print('📥 GET REQUEST WITH QUERY PARAMS');
      // print('Endpoint: $endpoint');
      // print('Full URL: ${uri.toString()}');
      // print('Query Parameters:');
      queryParams.forEach((key, value) {
        // print('  $key: $value');
      });
      // print('═══════════════════════════════════════════════════════');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Exception('Ошибка сети: ${e.message}');
    } on TimeoutException {
      throw Exception('Превышено время ожидания ответа от сервера');
    } catch (e) {
      if (e.toString().contains('Token expired')) {
        rethrow; // Пропустить Token expired
      }
      throw Exception('Неизвестная ошибка');
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

      // print('═══════════════════════════════════════════════════════');
      // print('📤 PUT REQUEST');
      // print('URL: $baseUrl$endpoint');
      // print('Token provided: ${effectiveToken != null}');
      if (effectiveToken != null) {
        // print('Token preview: ${effectiveToken.substring(0, 30)}...');
        // print('Token type: JWT');
      }
      // print('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // print('  $key: Bearer [HIDDEN]');
        } else {
          // print('  $key: $value');
        }
      });
      // print('Body: $body');
      // print('═══════════════════════════════════════════════════════');

      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      print('⚠️ PUT RAW RESPONSE: statusCode=${response.statusCode}');
      print('⚠️ PUT RESPONSE BODY: ${response.body}');
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

      // print('═══════════════════════════════════════════════════════');
      // print('🗑️ DELETE REQUEST');
      // print('URL: $baseUrl$endpoint');
      // print('Token provided: ${effectiveToken != null}');
      if (effectiveToken != null) {
        // print('Token preview: ${effectiveToken.substring(0, 30)}...');
        // print('Token type: JWT');
      }
      // print('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // print('  $key: Bearer [HIDDEN]');
        } else {
          // print('  $key: $value');
        }
      });
      if (body != null) {
        // print('Body: $body');
      }
      // print('═══════════════════════════════════════════════════════');

      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));

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
  /// 1. На первой попытке пробует обновить токен (с debounce защитой)
  /// 2. Повторяет запрос с новым токеном
  /// 3. Если токен все еще невалиден - отправляет сигнал об истечении токена
  ///
  /// Автоматически повторяет запросы с задержкой: 1s, 2s, 4s, 8s
  static Future<Map<String, dynamic>> _retryRequest(
    Future<Map<String, dynamic>> Function() request,
    String endpoint,
  ) async {
    int tokenExpiredAttempts = 0;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await request();
      } on TokenExpiredException {
        // 401 — токен истёк, пробуем обновить один раз
        if (tokenExpiredAttempts == 0) {
          tokenExpiredAttempts++;

          // Защита от слишком частых refresh запросов (debounce)
          final now = DateTime.now();
          final lastRefresh = _lastTokenRefreshAttempt;
          if (lastRefresh != null) {
            final timeSinceLastRefresh = now.difference(lastRefresh).inSeconds;
            if (timeSinceLastRefresh < _tokenRefreshMinIntervalSeconds) {
              // Слишком много попыток refresh подряд - отправляем TokenExpiredEvent
              throw TokenExpiredException('Token refresh rate limit exceeded');
            }
          }

          _lastTokenRefreshAttempt = now;

          // print('🔄 ApiService: 401 перехвачен, пробуем refresh токена...');
          final currentToken = HiveService.getUserData('token') as String?;
          if (currentToken != null && currentToken.isNotEmpty) {
            try {
              final newToken = await refreshToken(currentToken);
              if (newToken != null && newToken.isNotEmpty) {
                // print('✅ ApiService: токен обновлён, повторяем запрос...');
                // Повторяем запрос - при следующей итерации он будет использовать новый токен
                // continue; перейдет к следующей итерации for цикла
                continue;
              } else {
                // print('❌ ApiService: refresh вернул пустой токен');
                throw TokenExpiredException(
                  'Token refresh returned empty token',
                );
              }
            } catch (e) {
              // print('❌ ApiService: ошибка при refresh: $e');
              throw TokenExpiredException('Token refresh failed: $e');
            }
          } else {
            // print('❌ ApiService: нет сохраненного токена для refresh');
            throw TokenExpiredException('No saved token to refresh');
          }
        } else {
          // Вторая попытка все еще вернула 401 - токен реально истёк
          // print('❌ ApiService: второй раз получена ошибка 401, отправляем TokenExpiredEvent');
          rethrow;
        }
      } on RateLimitException {
        if (attempt < _maxRetries - 1) {
          final delayMs = _retryDelayMs * (1 << attempt); // Exponential backoff
          // print('⏳ ApiService: rate limit - ждем ${delayMs}ms перед повтором...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          // print('❌ Максимум попыток достигнут. Прекращаю retry.');
          rethrow;
        }
      }
    }
    throw Exception('Failed after $_maxRetries attempts');
  }

  /// Обрабатывает ответ от сервера.
  static Map<String, dynamic> _handleResponse(http.Response response) {
    // print('✅ API Response status: ${response.statusCode}');
    // print('📋 Response body: ${response.body}');
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // print('✅ Request successful!');
      return data;
    } else if (response.statusCode == 429) {
      // Rate limit - signal to retry
      // print('⚠️ 429 Too Many Requests - Rate limited');
      // print('Error response: ${data['message'] ?? 'Too many requests'}');
      throw RateLimitException('429 Too Many Requests');
    } else if (response.statusCode == 401) {
      // print('❌ 401 Unauthorized - Token might be expired or invalid');
      // print('Error response: ${data['message'] ?? 'Token expired'}');
      // Бросаем типизированное исключение для перехвата в _retryRequestWithRefresh
      throw TokenExpiredException(data['message'] ?? 'Token expired');
    } else if (response.statusCode == 422) {
      // Validation error - return response with errors
      // print('❌ 422 Validation Error');
      // print('Full error response: ${jsonEncode(data)}');
      if (data['errors'] is Map) {
        // print('\n📋 Detailed validation errors:');
        (data['errors'] as Map).forEach((key, value) {
          // print('  ❌ $key: $value');
          if (key == 'attributes' && value is List) {
            // print('     ^ ATTRIBUTES error! Check field structure');
          }
        });
      }
      // Don't throw exception, let calling code handle it
      return data;
    } else if (response.statusCode == 500) {
      // print('❌ 500 Server Error');
      // print('Error message: ${data['message'] ?? 'Server error'}');
      throw Exception(data['message'] ?? 'Ошибка сервера');
    } else {
      // print('❌ Error with status ${response.statusCode}');
      // print('Error response: ${data['message'] ?? 'Ошибка сервера'}');
      return data; // Return the response so caller can handle it
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

      // print();
      // print('   response type: ${response.runtimeType}');
      // print('   data type: ${response['data']?.runtimeType}');

      // API возвращает: {"success":true,"data":[{"type":{...},"attributes":[...]}]}
      // data - это List с одним элементом
      final dataNode = response['data'];

      List<dynamic>? attributesJson;

      if (dataNode is List && dataNode.isNotEmpty) {
        // data это List - берём первый элемент
        final firstItem = dataNode[0] as Map<String, dynamic>?;
        attributesJson = firstItem?['attributes'] as List<dynamic>?;
        // print();
      } else if (dataNode is Map<String, dynamic>) {
        // data это Map - берём attributes напрямую
        attributesJson = dataNode['attributes'] as List<dynamic>?;
        // print();
      }

      if (attributesJson == null || attributesJson.isEmpty) {
        // print('   ❌ No attributes found in response');
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
            // print();
          }
        } catch (e) {
          // print('   ⚠️ Failed to parse attribute at index $i: $e');
        }
      }

      // print('   ✅ Total parsed: ${attributes.length} attributes');
      return attributes;
    } catch (e) {
      // print('❌ getAdvertCreationAttributes error: $e');
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
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (catalogId != null) queryParams['catalog_id'] = catalogId;
      if (sort != null) queryParams['sort'] = sort;
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      // Добавляем фильтры
      if (filters != null && filters.isNotEmpty) {
        print('📦 API getAdverts - Processing filters:');
        filters.forEach((key, value) {
          // 🟢 СПЕЦИАЛЬНАЯ ОБРАБОТКА для filters[value_selected] (для атрибутов выбранных значений, ID < 1000)
          if (key == 'value_selected' && value is Map<String, dynamic>) {
            print('   📍 Processing value_selected:');
            // filters[value_selected][attr_id][0], [1] и т.д. - выбранные ID значений
            value.forEach((attrId, attrValue) {
              if (attrValue is Set) {
                // Множественный выбор: Set<String> с ID выбранных значений
                final setList = (attrValue as Set).toList();
                if (setList.isNotEmpty) {
                  for (int i = 0; i < setList.length; i++) {
                    final paramKey = 'filters[value_selected][$attrId][$i]';
                    queryParams[paramKey] = setList[i].toString();
                    print('      ✅ $paramKey = ${setList[i].toString()}');
                  }
                }
              } else if (attrValue is List) {
                // Список значений
                if ((attrValue as List).isNotEmpty) {
                  for (int i = 0; i < (attrValue as List).length; i++) {
                    final paramKey = 'filters[value_selected][$attrId][$i]';
                    queryParams[paramKey] = attrValue[i].toString();
                    print('      ✅ $paramKey = ${attrValue[i].toString()}');
                  }
                }
              } else {
                // Простое значение
                final paramKey = 'filters[value_selected][$attrId]';
                queryParams[paramKey] = attrValue.toString();
                print('      ✅ $paramKey = ${attrValue.toString()}');
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
                    // print('  ✅ $paramKey = ${rangeValue.toString()}');
                  }
                });
              } else if (attrValue is Set) {
                // Множественный выбор
                final setList = (attrValue as Set).toList();
                if (setList.isNotEmpty) {
                  for (int i = 0; i < setList.length; i++) {
                    final paramKey = 'filters[values][$attrId][$i]';
                    queryParams[paramKey] = setList[i].toString();
                    // print('  ✅ $paramKey = ${setList[i].toString()}');
                  }
                }
              } else if (attrValue is List) {
                // Список значений
                if ((attrValue as List).isNotEmpty) {
                  for (int i = 0; i < (attrValue as List).length; i++) {
                    final paramKey = 'filters[values][$attrId][$i]';
                    queryParams[paramKey] = attrValue[i].toString();
                    // print('  ✅ $paramKey = ${attrValue[i].toString()}');
                  }
                }
              } else {
                // Простое значение (boolean и другие)
                final paramKey = 'filters[values][$attrId]';
                queryParams[paramKey] = attrValue.toString();
                // print('  ✅ $paramKey = ${attrValue.toString()}');
              }
            });
          } else if (value is Map<String, dynamic>) {
            // Вложенные Map (например {min: 1, max: 5}) - обработка для остальных структур
            value.forEach((subKey, subValue) {
              final paramKey = 'filters[$key][$subKey]';
              queryParams[paramKey] = subValue.toString();
              // print('  ✅ $paramKey = ${subValue.toString()}');
            });
          } else if (value is Set) {
            // Множественный выбор (Set<String>)
            // ⚠️ ВАЖНО: создаём РАЗНЫЕ ключи для каждого элемента!
            final setList = (value as Set).toList();
            if (setList.isNotEmpty) {
              for (int i = 0; i < setList.length; i++) {
                final paramKey = 'filters[$key][$i]';
                queryParams[paramKey] = setList[i].toString();
                // print('  ✅ $paramKey = ${setList[i].toString()}');
              }
            }
          } else if (value is List) {
            // Список значений
            // ⚠️ ВАЖНО: создаём РАЗНЫЕ ключи для каждого элемента!
            if ((value as List).isNotEmpty) {
              for (int i = 0; i < (value as List).length; i++) {
                final paramKey = 'filters[$key][$i]';
                queryParams[paramKey] = value[i].toString();
                // print('  ✅ $paramKey = ${value[i].toString()}');
              }
            }
          } else {
            // Простые значения (строки, числа)
            final paramKey = 'filters[$key]';
            queryParams[paramKey] = value.toString();
            // print('  ✅ $paramKey = ${value.toString()}');
          }
        });
      }

      // print('📋 Query Parameters:');
      queryParams.forEach((key, value) {
        print('  📋 $key: $value');
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

      print('\n🔗 FULL REQUEST URL:');
      print(
        '   GET /adverts?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&')}',
      );
      print('');

      final response = await getWithQuery(
        '/adverts',
        queryParams,
        token: token,
      );

      // � Успешно получен ответ от API
      // Клиентская фильтрация будет применена на уровне RealEstateListingsScreen
      // если необходимо (fallback стратегия)

      return AdvertsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load adverts: $e');
    }
  }

  /// Получить одно объявление по ID.
  static Future<Advert> getAdvert(int id, {String? token}) async {
    try {
      final response = await get('/adverts/$id', token: token);
      final data = response['data'];
      if (data is List) {
        return Advert.fromJson(data[0] as Map<String, dynamic>);
      } else {
        return Advert.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
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
      print('⚠️  Failed to load attributes for advert $id: $e');
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
  static Future<CatalogsResponse> getCatalogs({String? token}) async {
    try {
      final response = await get('/content/catalogs', token: token);
      return CatalogsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load catalogs: $e');
    }
  }

  /// Получить каталог с категориями по ID.
  static Future<CatalogWithCategories> getCatalog(
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

      return CatalogWithCategories.fromJson(
        dataList[0] as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception('Failed to load catalog: $e');
    }
  }

  /// Получить категорию по ID.
  static Future<Category> getCategory(int categoryId, {String? token}) async {
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

      return Category.fromJson(dataList[0] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load category: $e');
    }
  }

  /// Поиск категорий.
  static Future<CategoriesResponse> searchCategories({
    required int catalogId,
    required String query,
    String? token,
  }) async {
    try {
      final response = await getWithQuery('/content/categories/search', {
        'catalog_id': catalogId,
        'q': query,
      }, token: token);
      return CategoriesResponse.fromJson(response);
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
      // print('📊 Full filter JSON keys: ${data.keys.toList()}');
      if (data['filters'] is List) {
        final filtersList = data['filters'] as List;
        // print('📊 Filters count: ${filtersList.length}');
        for (int i = 0; i < filtersList.length; i++) {
          final filter = filtersList[i];
          // print('  [$i] ID=${filter['id']}, Title=${filter['title']}, Values=${filter['values']?.length ?? 0}');
          // print('       is_title_hidden=${filter['is_title_hidden']}, is_special_design=${filter['is_special_design']}');
        }
        // Сканируем все фильтры на предмет "Вам предложат цену"
        // print('🔍 Searching for "Вам предложат цену" filter...');
        bool found = false;
        for (final filter in filtersList) {
          final title = filter['title']?.toString() ?? '';
          if (title.contains('предложат') ||
              title.contains('цену') ||
              title.contains('offer') ||
              title.contains('price')) {
            // print('   ✅ Found possible match: ID=${filter['id']}, Title=$title');
            found = true;
          }
        }
        if (!found) {
          // print('   ❌ "Вам предложат цену" filter NOT found in API response!');
          // print('   NOTE: This filter is REQUIRED but not returned by API');
          // print('   It will be added programmatically in _loadAttributes()');
        }
      }
      try {
        // API returns: {"success":true,"data":{"sort":[...],"filters":[...]}}
        // data already contains {"sort": [...], "filters": [...]}
        // So we pass it directly to fromJson
        return MetaFiltersResponse.fromJson(data);
      } catch (parseError) {
        // print('🔴 ERROR parsing MetaFiltersResponse:');
        // print('   Error: $parseError');
        // print('   Data keys: ${data.keys}');
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
      // print('\n🚀 SENDING TO API: POST /adverts');
      // print('Full JSON:');
      // print(json);
      if (json['attributes'] != null) {
        // print('\nAttributes structure:');
        // print('  - value_selected: ${json['attributes']['value_selected']}');
        // print('  - values keys: ${json['attributes']['values']?.keys.toList()}');
        if (json['attributes']['values'] != null) {
          // print('  - values[1048]: ${json['attributes']['values']['1048']} (Type: ${json['attributes']['values']['1048'].runtimeType})');
          // print('  - values[1127]: ${json['attributes']['values']['1127']}');
          // print('  - values[1040]: ${json['attributes']['values']['1040']}');
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
      // print('\n🔄 SENDING TO API: PUT /adverts/$advertId');
      // print('Full JSON:');
      // print(json);
      if (json['attributes'] != null) {
        // print('\nAttributes structure:');
        // print('  - value_selected: ${json['attributes']['value_selected']}');
        // print('  - values keys: ${json['attributes']['values']?.keys.toList()}');
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

  /// Обновить токен доступа.
  static Future<String?> refreshToken(String currentToken) async {
    try {
      final response = await post(
        '/auth/refresh-token',
        {},
        token: currentToken,
      );
      final newToken = response['access_token'] as String?;
      if (newToken != null) {
        await HiveService.saveUserData('token', newToken);
      }
      return newToken;
    } catch (e) {
      // Если refresh не удался, вернуть null
      return null;
    }
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
      // print('Failed to save advert view: $e');
      // Не пробрасываем ошибку, так как это некритично
    }
  }

  /// Сохранить поделиться объявлением
  static Future<void> shareAdvert(int advertId, {String? token}) async {
    try {
      await post('/adverts/$advertId/share', {}, token: token);
    } catch (e) {
      // print('Failed to share advert: $e');
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

      // print('═══════════════════════════════════════════════════════');
      // print('📤 MULTIPART UPLOAD REQUEST');
      // print('URL: $baseUrl$endpoint');
      // print('Field name: $fieldName');
      // print('File: $filePath');
      // print('Token provided: ${token != null}');
      // print('═══════════════════════════════════════════════════════');

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
        // print('📎 Adding image $imageIndex: $filePath');
        final file = File(filePath);

        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('images[$imageIndex]', filePath),
          );
          imageIndex++;
        } else {
          // print('⚠️ File not found: $filePath');
        }
      }

      // Добавить существующие изображения (для сохранения текущих и/или изменения порядка)
      if (existingImages != null && existingImages.isNotEmpty) {
        for (int i = 0; i < existingImages.length; i++) {
          final existingFileName = existingImages[i];
          request.fields['images[${imageIndex + i}]'] = existingFileName;
          // print('📸 Preserving existing image: $existingFileName');
        }
      }

      // Добавить изображения для удаления (если требуется)
      if (deleteImages != null && deleteImages.isNotEmpty) {
        for (int i = 0; i < deleteImages.length; i++) {
          request.fields['delete_images[$i]'] = deleteImages[i];
          // print('🗑️ Marking for deletion: ${deleteImages[i]}');
        }
      }

      // Логирование запроса
      // print('════════════════════════════════════════════════════');
      // print('📤 MULTIPART REQUEST to /adverts/$advertId/images');
      // print('   Mode: ${deleteImages != null ? 'DELETE' : 'UPLOAD'}');
      // print('   New files: ${imagePaths.length}');
      if (existingImages != null && existingImages.isNotEmpty) {
        // print('   Existing: ${existingImages.length}');
      }
      if (deleteImages != null && deleteImages.isNotEmpty) {
        // print('   To delete: ${deleteImages.length}');
      }
      // print('════════════════════════════════════════════════════');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // print('тЬЕ API Response status: ${response.statusCode}');
      // print('ЁЯУЛ Response body: ${response.body}');

      if (response.statusCode == 200) {
        // print('✅ Images operation completed successfully!');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        // Токен истёк - пытаемся обновить и повторить
        // print('⚠️ Token expired (401), attempting to refresh...');
        final newToken = await refreshToken(token);
        if (newToken != null) {
          // print('✅ Token refreshed, retrying upload...');
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
      // print('тЭМ Error with image operation: $e');
      rethrow;
    }
  }

  /// Получить список регионов
  static Future<List<Map<String, dynamic>>> getRegions({String? token}) async {
    try {
      final headers = {...defaultHeaders};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('$baseUrl/addresses/regions');

      // print('═══════════════════════════════════════════════════════');
      // print('📥 GET REQUEST /addresses/regions');
      // print('URL: $uri');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      // print('✅ API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['data'] != null) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          return List<Map<String, dynamic>>.from(
            data.whereType<Map<String, dynamic>>(),
          );
        }
        return [];
      } else {
        throw Exception('Failed to get regions: ${response.statusCode}');
      }
    } catch (e) {
      // print('❌ Error getting regions: $e');
      throw Exception('Error getting regions: $e');
    }
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

      // print('═══════════════════════════════════════════════════════');
      // print('📥 GET REQUEST /addresses/search');
      // print('URL: $uri');
      // print('Token provided: ${token != null}');
      if (token != null) {
        // print('Token preview: ${token.substring(0, 30)}...');
      }
      // print('Headers:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          // print('  $key: Bearer [HIDDEN]');
        } else {
          // print('  $key: $value');
        }
      });
      // print('Body: ${jsonEncode(bodyMap)}');

      // Use http.Request to send GET with JSON body (unusual but API requires it)
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      request.body = jsonEncode(bodyMap);

      final streamResponse = await request.send().timeout(
        const Duration(seconds: 10),
      );
      final response = await http.Response.fromStream(streamResponse);

      // print('✅ API Response status: ${response.statusCode}');

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
      final response = await getWithQuery('/adverts/create', {
        'category_id': categoryId,
      }, token: token);

      // print('📦 getListingsFilterAttributes: Parsing for category $categoryId');

      // Если требуется токен и он истёк, обновить и повторить
      if (response is Map &&
          response['message'] != null &&
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
      if (response is Map && response['data'] is List) {
        final dataList = response['data'] as List<dynamic>;
        if (dataList.isNotEmpty && dataList[0] is Map) {
          final firstItem = dataList[0] as Map<String, dynamic>;
          attributes = firstItem['attributes'] as List<dynamic>? ?? [];
        }
      }

      // Вернуть весь ответ
      return {
        'success': true,
        'data': attributes,
        'message': response['message'],
      };
    } catch (e) {
      // print('❌ getListingsFilterAttributes error: $e');
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

      // print('✅ Price offer sent successfully for advert $advertId');
      return response;
    } catch (e) {
      // print('❌ Error submitting price offer: $e');
      rethrow;
    }
  }

  /// 💵 Получить список предложений цены для объявления
  /// GET /v1/me/offers/received/{slug}/{id}
  /// Возвращает список предложений с информацией о пользователе
  static Future<List<Map<String, dynamic>>> getPriceOffers({
    required int advertId,
    required String advertSlug,
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

      final queryParams = {'sort': sort, 'page': page};

      final response = await getWithQuery(
        '/me/offers/received/$advertSlug/$advertId',
        queryParams,
        token: effectiveToken,
      );

      // Возвращаем список предложений
      if (response['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (response['data'] as List).whereType<Map<String, dynamic>>(),
        );
      }

      return [];
    } catch (e) {
      // print('❌ Error getting price offers: $e');
      // Возвращаем пустой список вместо ошибки, чтобы не сломать UI
      return [];
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

        print('📊 getMyOffers() returned ${offers.length} offers');
        if (offers.isNotEmpty) {
          print('   First offer structure:');
          offers.first.forEach((key, value) {
            if (value is Map || value is List) {
              print('      $key: [object with keys]');
            } else {
              print('      $key: $value (${value.runtimeType})');
            }
          });
        }

        return offers;
      } else if (response['data'] == null) {
        return [];
      }

      // Другие типы - значит ошибка структуры

      return [];
    } catch (e) {
      print('❌ Error in getMyOffers: $e');
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
      // print('❌ Error getting offers received list: $e');
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
      // print('❌ Error getting all received offers: $e');
      return [];
    }
  }

  /// 💰 Обновить статус полученного предложения цены
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

      print(
        '🔄 Обновляем статус своего предложения #$offerId на статус $statusId',
      );
      print('   Endpoint: /me/offers/$offerId');
      print('   Body: $body');
      print('   ℹ️  Это МОЕ предложение которое я отправил');

      final response = await delete(
        '/me/offers/$offerId',
        token: effectiveToken,
        body: body,
      );

      print('✅ API Response received:');
      print('   Response type: ${response.runtimeType}');
      print('   Response keys: ${response.keys.toList()}');
      print('   Full response: $response');

      // Пытаемся получить success field - может быть во вложенной структуре
      var success = response['success'];
      var message = response['message'];
      var data = response['data'];

      print('   success field: $success (type: ${success.runtimeType})');
      print(
        '   message field: $message (type: ${message?.runtimeType ?? "null"})',
      );
      print('   data field: $data (type: ${data?.runtimeType ?? "null"})');

      // Проверяем успешность - success может быть true или в другой структуре
      if (success == true) {
        print('   ✅ Статус успешно обновлен!');
        return response;
      } else if (success == false) {
        final errMsg = message ?? 'Неизвестная ошибка';
        print('   ❌ API вернул success=false');
        print('   Message: $errMsg');
        throw Exception(errMsg);
      } else {
        // success может быть null или отсутствовать
        print('   ⚠️ Поле success имеет неожиданное значение: $success');
        if (message != null) {
          print('   Message: $message');
          throw Exception(message);
        } else {
          print(
            '   Предположим что операция успешна (success не присутствует)',
          );
          return response;
        }
      }
    } catch (e) {
      print('❌ Ошибка при обновлении статуса предложения: $e');
      rethrow; // Используем rethrow вместо throw Exception для сохранения stacktrace
    }
  }
}
