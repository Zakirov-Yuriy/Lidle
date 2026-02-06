class Message {
  final String senderName;
  final String? senderAvatar;
  final String lastMessageTime;
  final int unreadCount;
  final bool isInternal;
  final bool isCompany; // true если это компания, false если юзер

  Message({
    required this.senderName,
    this.senderAvatar,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isInternal,
    required this.isCompany,
  });
}
