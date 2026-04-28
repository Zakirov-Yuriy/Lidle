// ============================================================
// "Сервис: Управление контактной информацией пользователя"
// ============================================================

import 'api_service.dart';
import '../models/contact_model.dart';
import 'package:lidle/core/logger.dart';

class ContactService {
  /// Получить список телефонов пользователя.
  /// Возвращает список всех сохраненных телефонных номеров.
  static Future<PhonesResponse> getPhones({String? token}) async {
    try {
      final response = await ApiService.get(
        '/me/settings/phones',
        token: token,
      );
      return PhonesResponse.fromJson(response);
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        // Попытка обновить токен и повторить запрос
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return getPhones(token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Получить список email пользователя.
  /// Возвращает список всех сохраненных адресов электронной почты.
  static Future<EmailsResponse> getEmails({String? token}) async {
    try {
      final response = await ApiService.get(
        '/me/settings/emails',
        token: token,
      );
      return EmailsResponse.fromJson(response);
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        // Попытка обновить токен и повторить запрос
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return getEmails(token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Добавить новый телефон.
  /// [phone] - номер телефона в формате "+380657618861"
  static Future<ContactResponse> addPhone({
    required String phone,
    String? token,
  }) async {
    try {
      // log.d(
      //   '➕ ContactService.addPhone - Phone: $phone, Token: ${token != null ? 'YES' : 'NO'}',
      // );
      final body = {'phone': phone};

      final response = await ApiService.post(
        '/me/settings/phones',
        body,
        token: token,
      );
      return ContactResponse.fromJson(response);
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return addPhone(phone: phone, token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Добавить новый email.
  /// [email] - адрес электронной почты
  static Future<ContactResponse> addEmail({
    required String email,
    String? token,
  }) async {
    try {
      // log.d(
      //   '➕ ContactService.addEmail - Email: $email, Token: ${token != null ? 'YES' : 'NO'}',
      // );
      final body = {'email': email};

      final response = await ApiService.post(
        '/me/settings/emails',
        body,
        token: token,
      );
      return ContactResponse.fromJson(response);
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return addEmail(email: email, token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Обновить телефон.
  /// [id] - ID телефона для обновления
  /// [phone] - новый номер телефона
  static Future<ContactResponse> updatePhone({
    required int id,
    required String phone,
    String? token,
  }) async {
    try {
      // log.d(
      //   '🔄 ContactService.updatePhone - ID: $id, Phone: $phone, Token: ${token != null ? 'YES' : 'NO'}',
      // );
      final body = {'phone': phone};

      final response = await ApiService.put(
        '/me/settings/phones/$id',
        body,
        token: token,
      );
      return ContactResponse.fromJson(response);
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return updatePhone(id: id, phone: phone, token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Обновить email.
  /// [id] - ID email для обновления
  /// [email] - новый адрес электронной почты
  static Future<ContactResponse> updateEmail({
    required int id,
    required String email,
    String? token,
  }) async {
    try {
      // log.d(
      //   '🔄 ContactService.updateEmail - ID: $id, Email: $email, Token: ${token != null ? 'YES' : 'NO'}',
      // );
      final body = {'email': email};

      final response = await ApiService.put(
        '/me/settings/emails/$id',
        body,
        token: token,
      );
      return ContactResponse.fromJson(response);
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return updateEmail(id: id, email: email, token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Удалить телефон.
  /// [id] - ID телефона для удаления
  static Future<Map<String, dynamic>> deletePhone({
    required int id,
    String? token,
  }) async {
    return await ApiService.delete('/me/settings/phones/$id', token: token);
  }

  /// Обновить основной номер телефона профиля.
  /// Используется эндпоинт: PUT /me/settings/phone
  /// [phone] - новый основной номер телефона (например, "+380958489566")
  static Future<ContactResponse> updateMainPhone({
    required String phone,
    String? token,
  }) async {
    try {
      log.d(
        '📱 ContactService.updateMainPhone - Phone: $phone, Token: ${token != null ? 'YES' : 'NO'}',
      );
      final body = {'phone': phone};

      final response = await ApiService.put(
        '/me/settings/phone',
        body,
        token: token,
      );
      return ContactResponse.fromJson(response);
    } catch (e) {
      if (e.toString().contains('Token expired') && token != null) {
        final newToken = await ApiService.refreshToken(token);
        if (newToken != null) {
          return updateMainPhone(phone: phone, token: newToken);
        }
      }
      rethrow;
    }
  }

  /// Удалить email.
  /// [id] - ID email для удаления
  static Future<Map<String, dynamic>> deleteEmail({
    required int id,
    String? token,
  }) async {
    return await ApiService.delete('/me/settings/emails/$id', token: token);
  }
}
