abstract class MessagesState {}

class MessagesInitial extends MessagesState {}

class MessagesLoaded extends MessagesState {
  final List<Map<String, dynamic>> mainMessages;
  final List<Map<String, dynamic>> archivedMessages;

  final int totalUnread; // 0 = ещё не загружено с бэка

  MessagesLoaded({
    required this.mainMessages,
    required this.archivedMessages,
    this.totalUnread = 0,
  });
}
