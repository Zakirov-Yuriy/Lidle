import 'package:lidle/services/api_service.dart';
import 'package:lidle/core/logger.dart';

/// Модель для представления контакта, которой уже в LIDLE
class UserInLidle {
  final int id;
  final String name;
  final String phone;
  final String? avatar;
  final String? nickname;

  UserInLidle({
    required this.id,
    required this.name,
    required this.phone,
    this.avatar,
    this.nickname,
  });

  factory UserInLidle.fromJson(Map<String, dynamic> json) {
    return UserInLidle(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatar: json['avatar'] as String?,
      nickname: json['nickname'] as String?,
    );
  }
}

/// Сервис для проверки, какие контакты уже зарегистрированы в LIDLE
class ContactsCheckService {
  /// Проверяет, какие номера телефонов уже зарегистрированы в системе LIDLE
  /// 
  /// [phoneNumbers] - список номеров телефонов для проверки
  /// 
  /// Возвращает Map<phoneNumber, UserInLidle?> где:
  /// - userInLidle != null если номер зарегистрирован
  /// - userInLidle == null если номер не в системе
  static Future<Map<String, UserInLidle?>> checkPhoneNumbers(
    List<String> phoneNumbers, {
    String? token,
  }) async {
    if (phoneNumbers.isEmpty) {
      return {};
    }

    try {
      log.i('🔍 ContactsCheckService: Проверка ${phoneNumbers.length} номеров');

      final response = await ApiService.post(
        '/contacts/check',
        {
          'phone_numbers': phoneNumbers,
        },
        token: token,
      );

      // Предполагаем, что API возвращает список пользователей найденных по номерам
      // Формат: { "data": [{ "phone": "+7...", "id": 123, "name": "...", ... }] }
      final result = <String, UserInLidle?>{};

      if (response['data'] is List) {
        final users = (response['data'] as List)
            .map((u) => UserInLidle.fromJson(u as Map<String, dynamic>))
            .toList();

        // Создаем Map для быстрого поиска по номеру
        for (final user in users) {
          result[user.phone] = user;
        }

        // Добавляем null для номеров, которых нет в результатах
        for (final phone in phoneNumbers) {
          result.putIfAbsent(phone, () => null);
        }
      } else {
        // Если API вернул что-то другое, считаем все номера незарегистрированными
        for (final phone in phoneNumbers) {
          result[phone] = null;
        }
      }

      log.d(
          '✅ Найдено пользователей: ${result.values.where((u) => u != null).length}');
      return result;
    } catch (e) {
      log.e('❌ ContactsCheckService: Ошибка при проверке номеров: $e');
      // Если ошибка - возвращаем пустой результат (все считаются незарегистрированными)
      return {for (final phone in phoneNumbers) phone: null};
    }
  }

  /// Проверяет один номер телефона
  static Future<UserInLidle?> checkPhoneNumber(
    String phoneNumber, {
    String? token,
  }) async {
    final result = await checkPhoneNumbers([phoneNumber], token: token);
    return result[phoneNumber];
  }
}
