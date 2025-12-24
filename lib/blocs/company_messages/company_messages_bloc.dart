import 'package:flutter_bloc/flutter_bloc.dart';
import 'company_messages_event.dart';
import 'company_messages_state.dart';

class CompanyMessagesBloc extends Bloc<CompanyMessagesEvent, CompanyMessagesState> {
  CompanyMessagesBloc() : super(CompanyMessagesInitial()) {
    on<LoadCompanyMessages>(_onLoadMessages);
    on<ArchiveCompanyMessages>(_onArchiveMessages);
    on<UnarchiveCompanyMessages>(_onUnarchiveMessages);
  }

  List<Map<String, dynamic>> mainMessages = [
    {'name': 'Компания A', 'subtitle': 'был(а) сегодня', 'unreadCount': '2'},
    {'name': 'Компания B', 'subtitle': 'был(а) вчера', 'unreadCount': '1'},
    {'name': 'Компания C', 'subtitle': 'был(а) сегодня', 'unreadCount': '3'},
  ];

  List<Map<String, dynamic>> archivedMessages = [];

  void _onLoadMessages(LoadCompanyMessages event, Emitter<CompanyMessagesState> emit) {
    emit(CompanyMessagesLoaded(
      mainMessages: List.from(mainMessages),
      archivedMessages: List.from(archivedMessages),
    ));
  }

  void _onArchiveMessages(ArchiveCompanyMessages event, Emitter<CompanyMessagesState> emit) {
    final selectedMessages = <Map<String, dynamic>>[];
    for (final index in event.indices) {
      if (index < mainMessages.length) {
        selectedMessages.add(mainMessages[index]);
      }
    }
    archivedMessages.addAll(selectedMessages);
    // Remove in reverse order to maintain indices
    event.indices.sort((a, b) => b.compareTo(a));
    for (final index in event.indices) {
      if (index < mainMessages.length) {
        mainMessages.removeAt(index);
      }
    }
    emit(CompanyMessagesLoaded(
      mainMessages: List.from(mainMessages),
      archivedMessages: List.from(archivedMessages),
    ));
  }

  void _onUnarchiveMessages(UnarchiveCompanyMessages event, Emitter<CompanyMessagesState> emit) {
    final selectedMessages = <Map<String, dynamic>>[];
    for (final index in event.indices) {
      if (index < archivedMessages.length) {
        selectedMessages.add(archivedMessages[index]);
      }
    }
    mainMessages.addAll(selectedMessages);
    // Remove in reverse order
    event.indices.sort((a, b) => b.compareTo(a));
    for (final index in event.indices) {
      if (index < archivedMessages.length) {
        archivedMessages.removeAt(index);
      }
    }
    emit(CompanyMessagesLoaded(
      mainMessages: List.from(mainMessages),
      archivedMessages: List.from(archivedMessages),
    ));
  }
}
