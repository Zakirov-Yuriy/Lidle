abstract class CompanyMessagesState {}

class CompanyMessagesInitial extends CompanyMessagesState {}

class CompanyMessagesLoaded extends CompanyMessagesState {
  final List<Map<String, dynamic>> mainMessages;
  final List<Map<String, dynamic>> archivedMessages;

  CompanyMessagesLoaded({
    required this.mainMessages,
    required this.archivedMessages,
  });
}
