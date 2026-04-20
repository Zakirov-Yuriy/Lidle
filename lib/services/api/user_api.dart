// ============================================================
// User API — работа с профилем пользователя и его контактами.
// ============================================================
// Извлечено из lib/services/api_service.dart (строки 2285–2423).
// Логика идентична оригиналу; дубль `token ?? HiveService.getUserData('token')`
// заменён на ApiBase.requireToken().
//
// Методы:
//   - getUserProfile({userId})
//   - getUserPhones({userId})

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/api/_api_base.dart';

class UserApi {
  /// 👤 Получить информацию о пользователе по ID
  /// GET /v1/users/{id}
  /// Возвращает профиль пользователя с контактной информацией
  static Future<Map<String, dynamic>> getUserProfile({
    required int userId,
    String? token,
  }) async {
    try {
      log.d('👤 Getting user profile for userId: $userId');

      final effectiveToken = ApiBase.requireToken(token);

      final response =
          await ApiService.get('/users/$userId', token: effectiveToken);

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
      for (final phone in uniquePhones) {
        log.d('   📱 $phone');
      }

      return uniquePhones;
    } catch (e) {
      log.d('❌ Error getting user phones: $e');
      return [];
    }
  }
}
