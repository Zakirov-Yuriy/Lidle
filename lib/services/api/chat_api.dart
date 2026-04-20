// ============================================================
// Chat API — работа с чатами и сообщениями.
// ============================================================
// Извлечено из lib/services/api_service.dart (строки 2425–2630).
// Логика идентична оригиналу; дубль `token ?? HiveService.getUserData('token')`
// заменён на ApiBase.requireToken().
//
// Методы:
//   - getChats({page})
//   - getChatMessages(chatId, {page})
//   - sendMessage(chatId, messageText)
//   - startChat(userId, messageText)
//   - deleteChat(chatId)
//   - markMessageAsRead(chatId, messageId)

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/api/_api_base.dart';

class ChatApi {
  /// 💬 Получить список всех чатов
  /// GET /v1/chats
  static Future<List<Map<String, dynamic>>> getChats({
    int page = 1,
    String? token,
  }) async {
    try {
      final effectiveToken = ApiBase.requireToken(token);

      final response = await ApiService.getWithQuery(
        '/chats',
        {'page': page.toString()},
        token: effectiveToken,
      );

      if (response['data'] != null && response['data'] is List) {
        final chats = List<Map<String, dynamic>>.from(response['data'] as List);
        return chats;
      }

      return [];
    } catch (e) {
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
      final effectiveToken = ApiBase.requireToken(token);

      final response = await ApiService.getWithQuery(
        '/chats/$chatId/messages',
        {'page': page.toString()},
        token: effectiveToken,
      );

      if (response['data'] != null && response['data'] is List) {
        final messages =
            List<Map<String, dynamic>>.from(response['data'] as List);
        return messages;
      }

      return [];
    } catch (e) {
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
      final effectiveToken = ApiBase.requireToken(token);

      if (messageText.isEmpty) {
        throw Exception('Сообщение не может быть пустым');
      }

      log.d('📤 Отправляем сообщение в чат #$chatId...');

      final response = await ApiService.post(
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
      final effectiveToken = ApiBase.requireToken(token);

      if (messageText.isEmpty) {
        throw Exception('Сообщение не может быть пустым');
      }

      log.d('💬 Начинаем чат с пользователем #$userId...');

      final response = await ApiService.post(
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
      final effectiveToken = ApiBase.requireToken(token);

      log.d('🗑️ Удаляем чат #$chatId...');

      final response = await ApiService.delete(
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
      final effectiveToken = ApiBase.requireToken(token);

      log.d('✅ Отмечаем сообщение #$messageId как прочитанное...');

      final response = await ApiService.post(
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
}
