// ============================================================
// "API методы для работы с сообщениями и чатами"
// ============================================================

import 'package:lidle/core/network/http_client.dart';

/// Remote класс для всех операций с сообщениями и чатами.
///
/// Включает методы для:
/// - Получения списка чатов
/// - Получения сообщений в чате
/// - Отправки сообщений
/// - Управления чатами (удаление, пометка как прочитанное)
class MessagesRemote {
  /// Получить список чатов пользователя
  static Future<List<Map<String, dynamic>>> getChats({
    int? page,
    int? limit,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await HttpClient.getWithQuery(
        '/chats',
        queryParams,
        token: token,
      );

      final data = response['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load chats: $e');
    }
  }

  /// Получить сообщения в чате по ID
  static Future<List<Map<String, dynamic>>> getChatMessages(
    String chatId, {
    int? page,
    int? limit,
    String? token,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await HttpClient.getWithQuery(
        '/chats/$chatId/messages',
        queryParams,
        token: token,
      );

      final data = response['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load chat messages: $e');
    }
  }

  /// Отправить сообщение в чат
  static Future<Map<String, dynamic>> sendMessage(
    String chatId,
    String message, {
    String? token,
  }) async {
    try {
      final response = await HttpClient.post(
        '/chats/$chatId/messages',
        {
          'text': message,
        },
        token: token,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Начать новый чат с пользователем или по объявлению
  static Future<int?> startChat(
    int userId, {
    int? advertId,
    String? initialMessage,
    String? token,
  }) async {
    try {
      final body = {
        'user_id': userId,
        if (advertId != null) 'advert_id': advertId,
        if (initialMessage != null) 'message': initialMessage,
      };

      final response = await HttpClient.post(
        '/chats',
        body,
        token: token,
      );

      // Возвращаем ID созданного чата
      final data = response['data'];
      if (data is Map) {
        return (data as Map)['id'] as int?;
      } else if (data is List && data.isNotEmpty) {
        final firstItem = data[0] as Map<String, dynamic>;
        return firstItem['id'] as int?;
      }

      return null;
    } catch (e) {
      throw Exception('Failed to start chat: $e');
    }
  }

  /// Удалить чат
  static Future<bool> deleteChat(
    String chatId, {
    String? token,
  }) async {
    try {
      await HttpClient.delete('/chats/$chatId', token: token);
      return true;
    } catch (e) {
      throw Exception('Failed to delete chat: $e');
    }
  }

  /// Пометить сообщение как прочитанное
  static Future<bool> markMessageAsRead(
    String chatId,
    int messageId, {
    String? token,
  }) async {
    try {
      await HttpClient.post(
        '/chats/$chatId/messages/$messageId/read',
        {},
        token: token,
      );
      return true;
    } catch (e) {
      throw Exception('Failed to mark message as read: $e');
    }
  }
}
