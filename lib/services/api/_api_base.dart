// ============================================================
// Базовый helper для feature-specific API клиентов.
// Содержит общий метод получения токена — во всей ApiService
// повторяется один и тот же паттерн `token ?? HiveService.getUserData('token')`.
// ============================================================
//
// ВАЖНО: Никаких изменений в логике. Только вынос дубля в одно место.

import 'package:lidle/hive_service.dart';

class ApiBase {
  /// Возвращает токен: либо переданный, либо сохранённый в Hive.
  /// Бросает Exception если токен отсутствует.
  static String requireToken(String? token) {
    final effectiveToken = token ?? (HiveService.getUserData('token') as String?);
    if (effectiveToken == null) {
      throw Exception('Требуется авторизация');
    }
    return effectiveToken;
  }

  /// Аналогично requireToken, но возвращает null без исключения.
  static String? optionalToken(String? token) {
    return token ?? (HiveService.getUserData('token') as String?);
  }
}
