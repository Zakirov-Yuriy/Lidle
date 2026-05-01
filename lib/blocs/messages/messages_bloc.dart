import 'package:flutter_bloc/flutter_bloc.dart';
import 'messages_event.dart';
import 'messages_state.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/badge_service.dart';

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  /// TTL для сообщений — только L1 (RAM), 1 минута.
  static const Duration _cacheTTL = Duration(minutes: 1);

  MessagesBloc() : super(MessagesInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<ArchiveMessages>(_onArchiveMessages);
    on<UnarchiveMessages>(_onUnarchiveMessages);
    on<RefreshMessages>(_onRefreshMessages);
    on<UpdateMessageUnreadCount>(_onUpdateMessageUnreadCount); // 🔴 Новое событие
    on<SyncMainMessages>(_onSyncMainMessages); // 🔵 Синхронизация реальных данных
    
    // 🟢 Начальная загрузка (пустой список)
    add(const LoadMessages());
  }
  
  /// 🟢 Загруузить реальные сообщения с API
  /// Вызывается из messages_page.dart когда пользователь открывает страницу сообщений
  Future<void> loadMessagesFromAPI() async {
    try {
      // 🔐 Проверяем авторизацию перед загрузкой
      final token = TokenService.currentToken;
      if (token == null || token.isEmpty) {
        log.d('🟢 MessagesBloc.loadMessagesFromAPI: Пользователь не авторизован');
        return;
      }
      
      log.d('🟢 MessagesBloc.loadMessagesFromAPI: Начинаем загрузку реальных данных с API');
      
      // Загружаем чаты с API
      final apiChats = await ApiService.getChats();
      log.d('🟢 MessagesBloc.loadMessagesFromAPI: API вернул ${apiChats.length} чатов');
      
      if (apiChats.isEmpty) {
        log.d('⚠️ MessagesBloc: Пустой список чатов из API');
        return;
      }
      
      final realMessagesMap = <Map<String, dynamic>>[];
      for (int idx = 0; idx < apiChats.length; idx++) {
        final chat = apiChats[idx];
        
        final userData = chat['user'] as Map<String, dynamic>?;
        if (userData == null) {
          log.d('  [API $idx] ⚠️ user данные отсутствуют!');
          continue;
        }
        
        final name = '${userData['name'] ?? ''} ${userData['last_name'] ?? ''}'.trim();
        final unreadCount = chat['unread_count'] as int? ?? 0;
        
        log.d('  [API $idx] $name → unreadCount: $unreadCount');
        
        realMessagesMap.add({
          'name': name,
          'subtitle': 'сейчас',
          'unreadCount': unreadCount,
          'lastMessage': (chat['last_message'] as Map?)?.toString() ?? '',
          'senderAvatar': userData['avatar'],
        });
      }
      
      log.d('🟢 MessagesBloc: Обработано ${realMessagesMap.length} реальных сообщений');
      int totalUnread = realMessagesMap.fold<int>(0, (sum, msg) => sum + (msg['unreadCount'] as int? ?? 0));
      log.d('   Сумма unreadCount: $totalUnread');
      
      // Отправляем SyncMainMessages чтобы обновить mainMessages реальными данными
      log.d('🟢 MessagesBloc: Отправляем SyncMainMessages...');
      add(SyncMainMessages(realMessages: realMessagesMap));
    } catch (e, st) {
      log.d('❌ Ошибка загрузки с API: $e');
      log.d('❌ Stack: $st');
    }
  }

  /// 🔴 УДАЛЕНЫ ТЕСТОВЫЕ ДАННЫЕ - mainMessages теперь загружается только из API
  List<Map<String, dynamic>> mainMessages = [];

  List<Map<String, dynamic>> archivedMessages = [];

  void _onLoadMessages(LoadMessages event, Emitter<MessagesState> emit) {
    log.d('🔴 _onLoadMessages: Начало загрузки (forceRefresh: ${event.forceRefresh})');
    
    // 📖 Проверяем кеш если это не принудительное обновление
    if (!event.forceRefresh) {
      final cached = AppCacheService().get<Map<String, dynamic>>(
        CacheKeys.messagesData,
      );
      if (cached != null) {
        final cachedMain = cached['main'] as List? ?? [];
        log.d('🔴 Найдены кешированные данные: ${cachedMain.length} сообщений');
        int cachedSum = 0;
        for (final msg in cachedMain) {
          final count = (msg as Map)['unreadCount'];
          cachedSum += count is int ? count : int.tryParse(count.toString()) ?? 0;
        }
        log.d('🔴 Сумма unreadCount из кеша: $cachedSum');
        
        // 🔔 Обновляем бейдж из кешированных данных
        BadgeService().updateBadgeCount(cachedSum);
        
        emit(
          MessagesLoaded(
            mainMessages: List.from(cachedMain),
            archivedMessages: List.from(cached['archived'] ?? []),
          ),
        );
        return;
      }
    }

    log.d('🔴 Кеш не найден или forceRefresh=true, используем тестовые данные');
    log.d('🔴 mainMessages: ${mainMessages.length} элементов');
    int testSum = 0;
    for (final msg in mainMessages) {
      final count = msg['unreadCount'];
      testSum += count is int ? count : int.tryParse(count.toString()) ?? 0;
    }
    log.d('🔴 Сумма unreadCount тестовых данных: $testSum');
    
    // 🔔 Обновляем бейдж из тестовых данных
    BadgeService().updateBadgeCount(testSum);

    // 💾 Сохраняем в L1 (RAM) с TTL 1 мин
    AppCacheService().set<Map<String, dynamic>>(CacheKeys.messagesData, {
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

    // 💾 Обновляем кеш L1
    AppCacheService().set<Map<String, dynamic>>(CacheKeys.messagesData, {
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

    // 💾 Обновляем кеш L1
    AppCacheService().set<Map<String, dynamic>>(CacheKeys.messagesData, {
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

  /// Обновить список сообщений (используется для Polling)
  /// Эмитирует текущее состояние чтобы UI переотрисовалось
  void _onRefreshMessages(
    RefreshMessages event,
    Emitter<MessagesState> emit,
  ) {
    // Обновляем кеш L1
    AppCacheService().set<Map<String, dynamic>>(CacheKeys.messagesData, {
      'main': List.from(mainMessages),
      'archived': List.from(archivedMessages),
    }, ttl: _cacheTTL);

    // Эмитим новое состояние чтобы UI обновилось
    emit(
      MessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
  }

  /// 🔴 Обновить количество непрочитанных сообщений в чате
  void _onUpdateMessageUnreadCount(
    UpdateMessageUnreadCount event,
    Emitter<MessagesState> emit,
  ) {
    // Ищем сообщение по имени отправителя и обновляем unreadCount
    final messageIndex = mainMessages.indexWhere(
      (msg) => msg['name'] == event.senderName,
    );

    if (messageIndex >= 0) {
      mainMessages[messageIndex]['unreadCount'] = event.unreadCount;
      // Обновляем кеш L1
      AppCacheService().set<Map<String, dynamic>>(CacheKeys.messagesData, {
        'main': List.from(mainMessages),
        'archived': List.from(archivedMessages),
      }, ttl: _cacheTTL);

      // 🔔 Пересчитываем общее количество непрочитанных и обновляем бейдж
      int totalUnread = 0;
      for (final msg in mainMessages) {
        final count = msg['unreadCount'];
        totalUnread += count is int ? count : int.tryParse(count.toString()) ?? 0;
      }
      BadgeService().updateBadgeCount(totalUnread);

      emit(
        MessagesLoaded(
          mainMessages: List.from(mainMessages),
          archivedMessages: List.from(archivedMessages),
        ),
      );
    }
  }

  /// 🔵 Синхронизировать mainMessages с реальными Message данными из messages_page
  /// Обновляет mainMessages с реальным unreadCount вместо hardcoded значений
  void _onSyncMainMessages(
    SyncMainMessages event,
    Emitter<MessagesState> emit,
  ) {
    log.d('🔵 _onSyncMainMessages: Начало синхронизации');
    log.d('   До: mainMessages.length = ${mainMessages.length}, сумма unreadCount = ${mainMessages.fold<int>(0, (sum, msg) => sum + (msg['unreadCount'] is int ? msg['unreadCount'] as int : int.tryParse(msg['unreadCount'].toString()) ?? 0))}');
    log.d('   Получено event.realMessages.length = ${event.realMessages.length}');
    
    // Заменяем mainMessages на реальные данные
    mainMessages = event.realMessages;
    
    log.d('🔵 После синхронизации:');
    log.d('   mainMessages.length = ${mainMessages.length}');
    
    int totalUnread = 0;
    for (int i = 0; i < mainMessages.length; i++) {
      final count = mainMessages[i]['unreadCount'];
      final unreadInt = count is int ? count : int.tryParse(count.toString()) ?? 0;
      totalUnread += unreadInt;
      log.d('   [$i] ${mainMessages[i]['name']} → unreadCount: $count (type: ${count.runtimeType})');
    }
    log.d('   Сумма unreadCount = $totalUnread');
    
    // 🔔 Обновляем бейдж на иконке приложения с количеством всех непрочитанных сообщений
    BadgeService().updateBadgeCount(totalUnread);

    // Обновляем кеш L1
    AppCacheService().set<Map<String, dynamic>>(CacheKeys.messagesData, {
      'main': List.from(mainMessages),
      'archived': List.from(archivedMessages),
    }, ttl: _cacheTTL);

    log.d('🔵 Эмитируем MessagesLoaded с ${mainMessages.length} сообщениями');
    emit(
      MessagesLoaded(
        mainMessages: List.from(mainMessages),
        archivedMessages: List.from(archivedMessages),
      ),
    );
  }
}
