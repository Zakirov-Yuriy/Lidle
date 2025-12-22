
class Message {
  final String senderName;
  final String? senderAvatar;
  final String lastMessageTime;
  final int unreadCount;
  final bool isInternal;

  Message({
    required this.senderName,
    this.senderAvatar,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isInternal,
  });
}
