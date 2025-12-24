abstract class MessagesState {}

class MessagesInitial extends MessagesState {}

class MessagesLoaded extends MessagesState {
  final List<Map<String, dynamic>> mainMessages;
  final List<Map<String, dynamic>> archivedMessages;

  MessagesLoaded({
    required this.mainMessages,
    required this.archivedMessages,
  });
}
