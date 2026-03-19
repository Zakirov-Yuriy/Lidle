class Message {
  final String senderName;
  final String? senderAvatar;
  final String lastMessageTime;
  final int unreadCount;
  final bool isInternal;
  final bool isCompany; // true если это компания, false если юзер
  final String? userId; // ID продавца/пользователя
  final int? chatId; // ID чата в системе
  final String? lastMessage; // Последнее сообщение в чате
  final String? advertTitle; // Название объявления
  final String? advertImage; // Изображение объявления
  final String? advertPrice; // Цена объявления
  final String? advertisementId; // ID объявления

  Message({
    required this.senderName,
    this.senderAvatar,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isInternal,
    required this.isCompany,
    this.userId,
    this.chatId,
    this.lastMessage,
    this.advertTitle,
    this.advertImage,
    this.advertPrice,
    this.advertisementId,
  });

  /// Копирование с изменениями
  Message copyWith({
    String? senderName,
    String? senderAvatar,
    String? lastMessageTime,
    int? unreadCount,
    bool? isInternal,
    bool? isCompany,
    String? userId,
    int? chatId,
    String? lastMessage,
    String? advertTitle,
    String? advertImage,
    String? advertPrice,
    String? advertisementId,
  }) {
    return Message(
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isInternal: isInternal ?? this.isInternal,
      isCompany: isCompany ?? this.isCompany,
      userId: userId ?? this.userId,
      chatId: chatId ?? this.chatId,
      lastMessage: lastMessage ?? this.lastMessage,
      advertTitle: advertTitle ?? this.advertTitle,
      advertImage: advertImage ?? this.advertImage,
      advertPrice: advertPrice ?? this.advertPrice,
      advertisementId: advertisementId ?? this.advertisementId,
    );
  }
}
