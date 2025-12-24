import 'package:flutter_bloc/flutter_bloc.dart';
import 'messages_event.dart';
import 'messages_state.dart';

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc() : super(MessagesInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<ArchiveMessages>(_onArchiveMessages);
    on<UnarchiveMessages>(_onUnarchiveMessages);
  }

  List<Map<String, dynamic>> mainMessages = [
    {'name': 'Данил Данилов', 'subtitle': 'был(а) сегодня', 'unreadCount': '1'},
    {'name': 'Егор Егоров', 'subtitle': 'был(а) сегодня', 'unreadCount': '4'},
    {'name': 'Ольга Якина', 'subtitle': 'был(а) сегодня', 'unreadCount': '4'},
    {'name': 'Андрей Андреев', 'subtitle': 'был(а) сегодня', 'unreadCount': '4'},
  ];

  List<Map<String, dynamic>> archivedMessages = [];

  void _onLoadMessages(LoadMessages event, Emitter<MessagesState> emit) {
    emit(MessagesLoaded(
      mainMessages: List.from(mainMessages),
      archivedMessages: List.from(archivedMessages),
    ));
  }

  void _onArchiveMessages(ArchiveMessages event, Emitter<MessagesState> emit) {
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
    emit(MessagesLoaded(
      mainMessages: List.from(mainMessages),
      archivedMessages: List.from(archivedMessages),
    ));
  }

  void _onUnarchiveMessages(UnarchiveMessages event, Emitter<MessagesState> emit) {
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
    emit(MessagesLoaded(
      mainMessages: List.from(mainMessages),
      archivedMessages: List.from(archivedMessages),
    ));
  }
}
