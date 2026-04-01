// ============================================================
// "Пользовательские исключения для работы с API"
// ============================================================

/// Исключение для 401 ошибок (токен истёк или невалиден).
/// Используется для перехвата и автоматического refresh токена.
///
/// **Используется в:**
/// - ApiService._handleResponse() — когда сервер вернёт 401
/// - ApiService._retryRequest() — для автоматического refresh и повтора
/// - BLoCs — для обработки истечения токена
class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException([this.message = 'Token expired']);

  @override
  String toString() => 'TokenExpiredException: $message';
}

/// Пользовательское исключение для 429 (rate limit) ошибок.
///
/// **Семантика:**
/// Сервер ограничил количество запросов. Нужно подождать перед повтором.
///
/// **Используется в:**
/// - ApiService._handleResponse() — когда сервер вернёт 429
/// - ApiService._retryRequest() — для exponential backoff повтора
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => 'RateLimitException: $message';
}
