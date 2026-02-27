import 'package:flutter_bloc/flutter_bloc.dart';
import 'messages_event.dart';
import 'messages_state.dart';
import 'package:lidle/core/cache/cacheable_bloc.dart';

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  static const String _cacheKey = 'messages_data';
  static const Duration _cacheTTL = Duration(minutes: 1);

  MessagesBloc() : super(MessagesInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<ArchiveMessages>(_onArchiveMessages);
    on<UnarchiveMessages>(_onUnarchiveMessages);
  }

  List<Map<String, dynamic>> mainMessages = [
    {'name': 'Данил Данилов', 'subtitle': 'был(а) сегодня', 'unreadCount': '1'},
    {'name': 'Егор Егоров', 'subtitle': 'был(а) сегодня', 'unreadCount': '4'},
    {'name': 'Ольга Якина', 'subtitle': 'был(а) сегодня', 'unreadCount': '4'},
    {
      'name': 'Андрей Андреев',
      'subtitle': 'был(а) сегодня',
      'unreadCount': '4',
    },
  ];

  List<Map<String, dynamic>> archivedMessages = [];

  void _onLoadMessages(LoadMessages event, Emitter<MessagesState> emit) {
    // 📖 Проверяем кеш если это не принудительное обновление
    if (!event.forceRefresh) {
      final cached = CacheManager().get<Map<String, dynamic>>(_cacheKey);
      if (cached != null) {
        // print('✅ Используем кешированные данные сообщений (TTL: 1 мин)');
        emit(
          MessagesLoaded(
            mainMessages: List.from(cached['main'] ?? []),
            archivedMessages: List.from(cached['archived'] ?? []),
          ),
        );
        return;
      }
    }

    // 💾 Сохраняем в кеш с TTL
    CacheManager().set<Map<String, dynamic>>(_cacheKey, {
      'main': List.from(mainMessages),
      'archived': List.from(archivedMessages),
    }, ttl: _cacheTTL);

    emit(
      MessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
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

    // 💾 Обновляем кеш
    CacheManager().set<Map<String, dynamic>>(_cacheKey, {
      'main': List.from(mainMessages),
      'archived': List.from(archivedMessages),
    }, ttl: _cacheTTL);

    emit(
      MessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
  }

  void _onUnarchiveMessages(
    UnarchiveMessages event,
    Emitter<MessagesState> emit,
  ) {
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

    // 💾 Обновляем кеш
    CacheManager().set<Map<String, dynamic>>(_cacheKey, {
      'main': List.from(mainMessages),
      'archived': List.from(archivedMessages),
    }, ttl: _cacheTTL);

    emit(
      MessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
  }
}

