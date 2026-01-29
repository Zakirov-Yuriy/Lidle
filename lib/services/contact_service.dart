// ============================================================
// "Сервис: Управление контактной информацией пользователя"
// ============================================================

import 'api_service.dart';
import '../models/contact_model.dart';

class ContactService {
  /// Получить список телефонов пользователя.
  /// Возвращает список всех сохраненных телефонных номеров.
  static Future<PhonesResponse> getPhones({String? token}) async {
    final response = await ApiService.get('/me/settings/phones', token: token);
    return PhonesResponse.fromJson(response);
  }

  /// Получить список email пользователя.
  /// Возвращает список всех сохраненных адресов электронной почты.
  static Future<EmailsResponse> getEmails({String? token}) async {
    final response = await ApiService.get('/me/settings/emails', token: token);
    return EmailsResponse.fromJson(response);
  }

  /// Добавить новый телефон.
  /// [phone] - номер телефона в формате "+380657618861"
  static Future<ContactResponse> addPhone({
    required String phone,
    String? token,
  }) async {
    print(
      '➕ ContactService.addPhone - Phone: $phone, Token: ${token != null ? 'YES' : 'NO'}',
    );
    final body = {'phone': phone};

    final response = await ApiService.post(
      '/me/settings/phones',
      body,
      token: token,
    );
    return ContactResponse.fromJson(response);
  }

  /// Добавить новый email.
  /// [email] - адрес электронной почты
  static Future<ContactResponse> addEmail({
    required String email,
    String? token,
  }) async {
    print(
      '➕ ContactService.addEmail - Email: $email, Token: ${token != null ? 'YES' : 'NO'}',
    );
    final body = {'email': email};

    final response = await ApiService.post(
      '/me/settings/emails',
      body,
      token: token,
    );
    return ContactResponse.fromJson(response);
  }

  /// Обновить телефон.
  /// [id] - ID телефона для обновления
  /// [phone] - новый номер телефона
  static Future<ContactResponse> updatePhone({
    required int id,
    required String phone,
    String? token,
  }) async {
    print(
      '🔄 ContactService.updatePhone - ID: $id, Phone: $phone, Token: ${token != null ? 'YES' : 'NO'}',
    );
    final body = {'phone': phone};

    final response = await ApiService.put(
      '/me/settings/phones/$id',
      body,
      token: token,
    );
    return ContactResponse.fromJson(response);
  }

  /// Обновить email.
  /// [id] - ID email для обновления
  /// [email] - новый адрес электронной почты
  static Future<ContactResponse> updateEmail({
    required int id,
    required String email,
    String? token,
  }) async {
    print(
      '🔄 ContactService.updateEmail - ID: $id, Email: $email, Token: ${token != null ? 'YES' : 'NO'}',
    );
    final body = {'email': email};

    final response = await ApiService.put(
      '/me/settings/emails/$id',
      body,
      token: token,
    );
    return ContactResponse.fromJson(response);
  }

  /// Удалить телефон.
  /// [id] - ID телефона для удаления
  static Future<Map<String, dynamic>> deletePhone({
    required int id,
    String? token,
  }) async {
    return await ApiService.delete('/me/settings/phones/$id', token: token);
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
