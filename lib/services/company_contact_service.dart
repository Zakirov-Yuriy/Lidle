// ============================================================
// "Сервис: Контактные данные КОМПАНИИ"
// ============================================================
// Отдельные от пользователя контакты компании. Скалярные поля
// (название/описание/email/телефон/адрес) лежат в company_contacts и
// сохраняются через PUT /me/settings/company/*. Множественные контакты
// (телефоны/почты/telegram/max) — это user_* со scope='company' и доступны
// через apiResource /me/settings/company/{phones|emails|telegrams|maxes}.
// Публичный профиль компании читается через GET /companies/{userId}.
// ============================================================

import 'package:lidle/services/api_service.dart';

class CompanyContactService {
  // ───── Публичный профиль компании (скаляры + адрес с названиями) ─────
  /// GET /companies/{userId} → {name, about, email, phone, address{...},
  /// phones[], emails[], telegrams[], maxes[]}.
  static Future<Map<String, dynamic>> getCompanyProfile({
    required int userId,
    String? token,
  }) {
    return ApiService.get('/companies/$userId', token: token);
  }

  // ───── Скалярные поля компании (company_contacts) ─────
  static Future<Map<String, dynamic>> changeName({
    required String name,
    String? token,
  }) {
    return ApiService.put('/me/settings/company/name', {'name': name},
        token: token);
  }

  static Future<Map<String, dynamic>> changeAbout({
    required String about,
    String? token,
  }) {
    return ApiService.put('/me/settings/company/about', {'about': about},
        token: token);
  }

  static Future<Map<String, dynamic>> changeEmail({
    required String email,
    String? token,
  }) {
    return ApiService.put('/me/settings/company/email', {'email': email},
        token: token);
  }

  static Future<Map<String, dynamic>> changePhone({
    required String phone,
    String? token,
  }) {
    return ApiService.put('/me/settings/company/phone', {'phone': phone},
        token: token);
  }

  static Future<Map<String, dynamic>> changeAddress({
    required int cityId,
    int? streetId,
    int? buildingId,
    String? token,
  }) {
    final body = <String, dynamic>{'city_id': cityId};
    if (streetId != null) body['street_id'] = streetId;
    if (buildingId != null) body['building_id'] = buildingId;
    return ApiService.put('/me/settings/company/address', body, token: token);
  }

  // ───── Телефоны компании ─────
  static Future<Map<String, dynamic>> getPhones({String? token}) {
    return ApiService.get('/me/settings/company/phones', token: token);
  }

  static Future<Map<String, dynamic>> addPhone({
    required String phone,
    String? token,
  }) {
    return ApiService.post('/me/settings/company/phones', {'phone': phone},
        token: token);
  }

  static Future<Map<String, dynamic>> updatePhone({
    required int id,
    required String phone,
    String? token,
  }) {
    return ApiService.put('/me/settings/company/phones/$id', {'phone': phone},
        token: token);
  }

  // ───── Почты компании ─────
  static Future<Map<String, dynamic>> getEmails({String? token}) {
    return ApiService.get('/me/settings/company/emails', token: token);
  }

  static Future<Map<String, dynamic>> addEmail({
    required String email,
    String? token,
  }) {
    return ApiService.post('/me/settings/company/emails', {'email': email},
        token: token);
  }

  static Future<Map<String, dynamic>> updateEmail({
    required int id,
    required String email,
    String? token,
  }) {
    return ApiService.put('/me/settings/company/emails/$id', {'email': email},
        token: token);
  }

  // ───── Telegram компании ─────
  static Future<Map<String, dynamic>> getTelegrams({String? token}) {
    return ApiService.get('/me/settings/company/telegrams', token: token);
  }

  static Future<Map<String, dynamic>> addTelegram({
    required String username,
    String? token,
  }) {
    return ApiService.post(
        '/me/settings/company/telegrams', {'username': username},
        token: token);
  }

  static Future<Map<String, dynamic>> updateTelegram({
    required int id,
    required String username,
    String? token,
  }) {
    return ApiService.put(
        '/me/settings/company/telegrams/$id', {'username': username},
        token: token);
  }

  // ───── MAX компании ─────
  static Future<Map<String, dynamic>> getMaxes({String? token}) {
    return ApiService.get('/me/settings/company/maxes', token: token);
  }

  static Future<Map<String, dynamic>> addMax({
    required String username,
    String? token,
  }) {
    return ApiService.post('/me/settings/company/maxes', {'username': username},
        token: token);
  }

  static Future<Map<String, dynamic>> updateMax({
    required int id,
    required String username,
    String? token,
  }) {
    return ApiService.put(
        '/me/settings/company/maxes/$id', {'username': username},
        token: token);
  }
}
