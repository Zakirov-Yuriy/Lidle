import 'package:lidle/models/home_models.dart';

/// 📝 Тип сообщения в чате
enum ChatMessageType {
  text,      // 💬 Обычное текстовое сообщение
  advert,    // 📦 Сообщение с объявлением (как карточка)
}

/// 💬 Модель сообщения для чата
class ChatMessage {
  final int? id;                    // ID сообщения в БД
  final ChatMessageType type;       // Тип сообщения
  final String? text;               // Текст для text-сообщений
  final Listing? advert;            // Объявление для advert-сообщений
  final bool isMe;                  // true = отправлено мной
  final String? createdAt;          // Время создания
  final String? readAt;             // Время прочтения (null = не прочитано)

  ChatMessage({
    this.id,
    required this.type,
    this.text,
    this.advert,
    required this.isMe,
    this.createdAt,
    this.readAt,
  });

  /// ✅ Копирование с изменениями
  ChatMessage copyWith({
    int? id,
    ChatMessageType? type,
    String? text,
    Listing? advert,
    bool? isMe,
    String? createdAt,
    String? readAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      advert: advert ?? this.advert,
      isMe: isMe ?? this.isMe,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
