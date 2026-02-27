import 'package:flutter_bloc/flutter_bloc.dart';
import 'company_messages_event.dart';
import 'company_messages_state.dart';
import 'package:lidle/core/cache/cacheable_bloc.dart';

class CompanyMessagesBloc
    extends Bloc<CompanyMessagesEvent, CompanyMessagesState> {
  static const String _cacheKey = 'company_messages_data';
  static const Duration _cacheTTL = Duration(minutes: 1);

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

  void _onLoadMessages(
    LoadCompanyMessages event,
    Emitter<CompanyMessagesState> emit,
  ) {
    // 📖 Проверяем кеш если это не принудительное обновление
    if (!event.forceRefresh) {
      final cached = CacheManager().get<Map<String, dynamic>>(_cacheKey);
      if (cached != null) {
        // print('✅ Используем кешированные данные корп. сообщений (TTL: 1 мин)');
        emit(
          CompanyMessagesLoaded(
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
      CompanyMessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
  }

  void _onArchiveMessages(
    ArchiveCompanyMessages event,
    Emitter<CompanyMessagesState> emit,
  ) {
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
      CompanyMessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
  }

  void _onUnarchiveMessages(
    UnarchiveCompanyMessages event,
    Emitter<CompanyMessagesState> emit,
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
      CompanyMessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
  }
}

