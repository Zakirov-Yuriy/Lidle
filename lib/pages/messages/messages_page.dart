import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/message_model.dart'; // Import Message model
import 'package:lidle/widgets/cards/message_card.dart'; // Import MessageCard
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/blocs/messages/messages_bloc.dart';
import 'package:lidle/blocs/messages/messages_event.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/pages/messages/chat_page.dart';
import 'package:lidle/services/messages_local_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/dialogs/delete_chat_dialog.dart';
import 'dart:async';
import 'package:lidle/core/logger.dart';

class MessagesPage extends StatefulWidget {
  // Renamed from MessagesEmptyPage
  const MessagesPage({super.key});

  static const String routeName = '/messages';

  @override
  State<MessagesPage> createState() => _MessagesPageState(); // Renamed from _MessagesEmptyPageState
}

class _MessagesPageState extends State<MessagesPage>
    with AutomaticKeepAliveClientMixin {
  bool isInternalChatSelected =
      true; // true для внутреннего чата, false для внешнего
  bool isCompaniesSelected = false; // 👤 false для юзеров (по умолчанию)
  bool isCompanyChatInternal =
      true; // true для внутреннего чата с компаниями, false для внешнего
  bool showCheckboxes = false; // Флаг для показа чекбоксов
  List<Message> messages = []; // Заполнитель для сообщений
  Timer? _updateTimer; // 🔄 Таймер для автоматического обновления счетчика
  
  // 🛡️ Защита от параллельных запросов и rate limit
  bool _isLoadingChatsBackground = false; // Флаг для предотвращения параллельных запросов
  int _rateLimitRetryCount = 0; // Счетчик попыток при rate limit
  Timer? _rateLimitTimer; // Таймер для восстановления после rate limit

  @override
  bool get wantKeepAlive => true; // 💾 Кешировать страницу в памяти

  bool _isInitialized = false; // 🔄 Флаг для загрузки только один раз

  // Dummy data for messages
  List<Message> dummyMessages = [
    // Юзеры - внутренний чат
    Message(
      senderName: 'Виталий Покрышкин',
      senderAvatar:
          'assets/profile_dashboard/Ellipse.png', // Assuming this asset exists
      lastMessageTime: 'был(а) сегодня',
      unreadCount: 4,
      isInternal: true,
      isCompany: false,
    ),
    Message(
      senderName: 'Григорий Цех',
      senderAvatar: null,
      lastMessageTime: 'был(а) сегодня',
      unreadCount: 15,
      isInternal: true,
      isCompany: false,
    ),
    Message(
      senderName: 'Иван Петров',
      senderAvatar: null,
      lastMessageTime: 'был(а) вчера',
      unreadCount: 2,
      isInternal: true,
      isCompany: false,
    ),
    // Юзеры - внешний чат
    Message(
      senderName: 'Данил',
      senderAvatar: null,
      lastMessageTime: 'был(а) 5 августа',
      unreadCount: 3,
      isInternal: false,
      isCompany: false,
    ),
    Message(
      senderName: 'Сергей',
      senderAvatar: null,
      lastMessageTime: 'был(а) неделю назад',
      unreadCount: 1,
      isInternal: false,
      isCompany: false,
    ),
    // Компании - внутренний чат
    Message(
      senderName: 'ОККО',
      senderAvatar: null,
      lastMessageTime: 'был(а) сегодня',
      unreadCount: 4,
      isInternal: true,
      isCompany: true,
    ),
    Message(
      senderName: 'Цветы Донец',
      senderAvatar: null,
      lastMessageTime: 'был(а) 5 августа',
      unreadCount: 3,
      isInternal: true,
      isCompany: true,
    ),
    Message(
      senderName: 'Колбасы и мясо',
      senderAvatar: null,
      lastMessageTime: 'был(а) сегодня',
      unreadCount: 15,
      isInternal: true,
      isCompany: true,
    ),
    // Компании - внешний чат
    Message(
      senderName: 'H&M',
      senderAvatar: null,
      lastMessageTime: 'был(а) недавно',
      unreadCount: 1,
      isInternal: false,
      isCompany: true,
    ),
    Message(
      senderName: 'Адидас',
      senderAvatar: null,
      lastMessageTime: 'был(а) день назад',
      unreadCount: 2,
      isInternal: false,
      isCompany: true,
    ),
    Message(
      senderName: 'Nike',
      senderAvatar: null,
      lastMessageTime: 'был(а) неделю назад',
      unreadCount: 0,
      isInternal: false,
      isCompany: true,
    ),
  ];

  // Keep track of selected messages for deletion/archive
  Map<int, bool> selectedMessages = {};

  @override
  void initState() {
    super.initState();
    //  Загружаем сообщения только при первом открытии экрана
    if (!_isInitialized) {
      _isInitialized = true;
      // 🔄 Ленивая загрузка сообщений при переходе на страницу
      context.read<MessagesBloc>().add(LoadMessages());
      _loadMessages();
      // 🔄 Запускаем таймер для автоматического обновления счетчика сообщений
      _startAutoUpdate();
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel(); // 🔴 Отменяем таймер при закрытии экрана
    _rateLimitTimer?.cancel(); // 🔴 Отменяем таймер rate limit
    super.dispose();
  }

  /// 🔄 Запустить периодическое обновление счетчика сообщений
  void _startAutoUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        // Загружаем обновленный список чатов с актуальным счетчиком
        _loadMessagesBackground();
      }
    });
    // log.d('✅ Таймер обновления счетчика сообщений запущен (интервал 15 сек)');
  }

  /// 💬 Загрузить список чатов в фоне (без показа лоадера)
  /// 🛡️ С защитой от параллельных запросов и rate limiting
  Future<void> _loadMessagesBackground() async {
    // 🛡️ Пропускаем если уже загружаются чаты
    if (_isLoadingChatsBackground) {
      // log.d('⏭️  Пропускаем загрузку (уже идет загрузка списка чатов)');
      return;
    }

    try {
      _isLoadingChatsBackground = true;
      
      // 📥 Загружаем чаты с API
      final apiChats = await ApiService.getChats();
      
      // Преобразуем API ответ в объекты Message, фильтруя локально удалённые чаты
      final loadedMessages = <Message>[];
      final deletedMap = MessagesLocalService.getDeletedChats();
      for (final chat in apiChats) {
        final userData = chat['user'] as Map<String, dynamic>;

        final userIdKey = userData['id']?.toString();
        final chatIdKey = chat['id']?.toString();
        final deletedIso = (userIdKey != null && deletedMap.containsKey(userIdKey))
            ? deletedMap[userIdKey]
            : (chatIdKey != null ? deletedMap[chatIdKey] : null);

        // Если чат помечен как локально удалённый — проверяем, пришло ли новое сообщение позже удаления
        if (deletedIso != null) {
          final unread = chat['unread_count'] as int? ?? 0;
          // Если есть непрочитанные — показываем
          if (unread <= 0) {
            String? lastMsgAt;
            if (chat['last_message'] != null && chat['last_message'] is Map) {
              lastMsgAt = (chat['last_message'] as Map)['created_at'] as String?;
            }
            lastMsgAt ??= chat['updated_at'] as String?;

            var show = false;
            if (lastMsgAt != null) {
              try {
                final lm = DateTime.parse(lastMsgAt);
                final del = DateTime.parse(deletedIso);
                if (lm.isAfter(del)) show = true;
              } catch (e) {
                // Если не получилось распарсить дату — показываем чат
                show = true;
              }
            }
            if (!show) continue; // фильтруем этот чат
          }
        }

        final message = Message(
          senderName:
              '${userData['name'] ?? ''} ${userData['last_name'] ?? ''}'
                  .trim(),
          senderAvatar: userData['avatar'],
          lastMessageTime: 'сейчас',
          unreadCount: chat['unread_count'] as int? ?? 0,
          isInternal: true,
          isCompany: false,
          userId: userData['id'].toString(),
          chatId: chat['id'] as int?,
        );
        loadedMessages.add(message);
      }

      if (mounted && loadedMessages.isNotEmpty) {
        // только если появились новые непрочитанные сообщения
        final hasChanges = loadedMessages.length != messages.length ||
            loadedMessages.asMap().entries.any((entry) =>
                entry.value.unreadCount !=
                (entry.key < messages.length ? messages[entry.key].unreadCount : -1));

        if (hasChanges) {
          // log.d('📨 Счетчик сообщений обновлен');
          setState(() {
            messages = loadedMessages;
          });
        }
      }
      
      // 🛡️ Сброс счетчика попыток при успехе
      _rateLimitRetryCount = 0;
    } catch (e) {
      // 🛡️ Обработка Rate Limit (429 Too Many Requests)
      if (e.toString().contains('429') || e.toString().contains('RateLimitException')) {
        _rateLimitRetryCount++;
        // Экспоненциальная задержка: 30сек, 60сек, 120сек...
        final delaySeconds = 30 * (1 << (_rateLimitRetryCount - 1));
        // log.d('⏸️  Rate limit на списке чатов! Попытка $_rateLimitRetryCount. Ждем ${delaySeconds}сек перед повторной попыткой...');
        
        // Отменяем текущий таймер
        _updateTimer?.cancel();
        
        // Запускаем новый таймер через задержку
        _rateLimitTimer = Timer(Duration(seconds: delaySeconds), () {
          if (mounted) {
            // log.d('🔄 Восстанавливаем периодическое обновление списка чатов');
            _startAutoUpdate();
          }
        });
      } else {
        log.d('⚠️  Ошибка фонового обновления счетчика: $e');
        _rateLimitRetryCount = 0;
      }
    } finally {
      _isLoadingChatsBackground = false;
    }
  }

  Future<void> _loadMessages() async {
    try {
      // 📥 Загружаем чаты с API
      final apiChats = await ApiService.getChats();
      
      // Преобразуем API ответ в объекты Message, фильтруя локально удалённые чаты
      final loadedMessages = <Message>[];
      final deletedMap = MessagesLocalService.getDeletedChats();
      for (final chat in apiChats) {
        final userData = chat['user'] as Map<String, dynamic>;

        final userIdKey = userData['id']?.toString();
        final chatIdKey = chat['id']?.toString();
        final deletedIso = (userIdKey != null && deletedMap.containsKey(userIdKey))
            ? deletedMap[userIdKey]
            : (chatIdKey != null ? deletedMap[chatIdKey] : null);

        if (deletedIso != null) {
          final unread = chat['unread_count'] as int? ?? 0;
          if (unread <= 0) {
            String? lastMsgAt;
            if (chat['last_message'] != null && chat['last_message'] is Map) {
              lastMsgAt = (chat['last_message'] as Map)['created_at'] as String?;
            }
            lastMsgAt ??= chat['updated_at'] as String?;

            var show = false;
            if (lastMsgAt != null) {
              try {
                final lm = DateTime.parse(lastMsgAt);
                final del = DateTime.parse(deletedIso);
                if (lm.isAfter(del)) show = true;
              } catch (e) {
                show = true;
              }
            }
            if (!show) continue;
          }
        }

        final message = Message(
          senderName:
              '${userData['name'] ?? ''} ${userData['last_name'] ?? ''}'
                  .trim(),
          senderAvatar: userData['avatar'],
          lastMessageTime: 'сейчас',
          unreadCount: chat['unread_count'] as int? ?? 0,
          isInternal: true,
          isCompany: false,
          userId: userData['id'].toString(),
          chatId: chat['id'] as int?,
        );
        loadedMessages.add(message);
      }

      // 🔄 Если API не вернул чаты, используем дамми данные
      if (loadedMessages.isEmpty) {
        messages = dummyMessages;
      } else {
        messages = loadedMessages;
      }
    } catch (e) {
      log.d('❌ Ошибка загрузки чатов: $e');
      // Fallback на дамми данные при ошибке
      messages = dummyMessages;
    }

    // Сохраняем в локальное хранилище для офлайн режима
    final messageMaps = messages
        .map(
          (msg) => {
            'senderName': msg.senderName,
            'senderAvatar': msg.senderAvatar,
            'lastMessageTime': msg.lastMessageTime,
            'unreadCount': msg.unreadCount,
            'isInternal': msg.isInternal,
            'isCompany': msg.isCompany,
            'userId': msg.userId,
            'chatId': msg.chatId,
            'lastMessage': msg.lastMessage,
            'advertTitle': msg.advertTitle,
            'advertImage': msg.advertImage,
            'advertisementId': msg.advertisementId,
          },
        )
        .toList();
    await MessagesLocalService.saveCurrentMessages(messageMaps);

    for (int i = 0; i < messages.length; i++) {
      selectedMessages[i] = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Преобразовать карты из локального хранилища в объекты Message
  List<Message> _convertMapsToMessages(List<Map<String, dynamic>> maps) {
    return maps.map((map) {
      return Message(
        senderName: map['senderName'] ?? '',
        senderAvatar: map['senderAvatar'],
        lastMessageTime: map['lastMessageTime'] ?? '',
        unreadCount: map['unreadCount'] ?? 0,
        isInternal: map['isInternal'] ?? true,
        isCompany: map['isCompany'] ?? false,
        userId: map['userId'],
        chatId: map['chatId'],
        lastMessage: map['lastMessage'],
        advertTitle: map['advertTitle'],
        advertImage: map['advertImage'],
        advertPrice: map['advertPrice'],
        advertisementId: map['advertisementId'],
      );
    }).toList();
  }

  /// Добавить новый чат в список и сохранить его
  Future<void> _addChatToMessages(Message chatMessage) async {
    // Если этот чат ранее был помечен как локально удалённый — снимаем метку,
    // т.к. пришло новое сообщение от этого пользователя/чата.
    final idKey = chatMessage.userId ?? (chatMessage.chatId?.toString());
    if (idKey != null) {
      await MessagesLocalService.removeDeletedChat(idKey);
    }
    // Проверяем, есть ли уже такой чат
    final existingIndex = messages.indexWhere((msg) =>
        msg.senderName == chatMessage.senderName &&
        msg.userId == chatMessage.userId);
    
    if (existingIndex >= 0) {
      // Обновляем существующий чат
      messages[existingIndex] = chatMessage;
    } else {
      // Добавляем новый чат в начало списка
      messages.insert(0, chatMessage);
    }
    
    // Сохраняем в локальное хранилище
    final messageMaps = messages
        .map(
          (msg) => {
            'senderName': msg.senderName,
            'senderAvatar': msg.senderAvatar,
            'lastMessageTime': msg.lastMessageTime,
            'unreadCount': msg.unreadCount,
            'isInternal': msg.isInternal,
            'isCompany': msg.isCompany,
            'userId': msg.userId,
            'chatId': msg.chatId,
            'lastMessage': msg.lastMessage,
            'advertTitle': msg.advertTitle,
            'advertImage': msg.advertImage,
            'advertisementId': msg.advertisementId,
          },
        )
        .toList();
    
    await MessagesLocalService.saveCurrentMessages(messageMaps);
    
    if (mounted) {
      setState(() {});
    }
  }

  static const accentColor = Color(0xFF00B7FF);

  @override
  Widget build(BuildContext context) {
    super.build(context); // 💾 Требуется для AutomaticKeepAliveClientMixin
    
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.read<MessagesBloc>().add(const LoadMessages());
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(onRetry: () {
              context.read<ConnectivityBloc>().add(const CheckConnectivityEvent());
            });
          }

          return BlocListener<NavigationBloc, NavigationState>(
            listener: (context, state) {
              if (!mounted) return;
              // Обрабатываем навигацию при выборе других пунктов меню
              if (state is NavigationToHome ||
                  state is NavigationToProfile ||
                  state is NavigationToFavorites ||
                  state is NavigationToAddListing ||
                  state is NavigationToMyPurchases) {
                context.read<NavigationBloc>().executeNavigation(context);
              }
            },
            child: Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 23),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [const Header(), const Spacer()],
                ),
              ),

              // ───── Back / Archive ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Возвращаемся на предыдущий экран через NavigationBloc
                        final navBloc = context.read<NavigationBloc>();
                        final previousIndex = navBloc.previousNavigationIndex;
                        navBloc.add(SelectNavigationIndexEvent(previousIndex));
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.arrow_back_ios,
                            color: activeIconColor,
                            size: 16,
                          ),
                          const SizedBox(
                            width: 0,
                          ), // Небольшой отступ между иконкой и текстом
                          const Text(
                            'Назад',
                            style: TextStyle(
                              color: activeIconColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/messages-archive',
                        );
                        if (result == true) {
                          await _loadMessages();
                        }
                      },
                      child: const Text(
                        'Архив',
                        style: TextStyle(color: activeIconColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // ───── Title ─────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Сообщения',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ───── Tabs ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First row: Companies / Users
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isCompaniesSelected) {
                                isCompanyChatInternal = true;
                              } else {
                                isInternalChatSelected = true;
                              }
                            });
                          },
                          child: Text(
                            'Внутренний чат',
                            style: TextStyle(
                              color:
                                  (isCompaniesSelected
                                      ? isCompanyChatInternal
                                      : isInternalChatSelected)
                                  ? accentColor
                                  : Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isCompaniesSelected) {
                                isCompanyChatInternal = false;
                              } else {
                                isInternalChatSelected = false;
                              }
                            });
                          },
                          child: Text(
                            'Внешний чат',
                            style: TextStyle(
                              color:
                                  (isCompaniesSelected
                                      ? isCompanyChatInternal
                                      : isInternalChatSelected)
                                  ? Colors.white
                                  : accentColor,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Stack(
                      children: [
                        Container(
                          height: 1,
                          width: double.infinity,
                          color: Colors.white24,
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          left:
                              (isCompaniesSelected
                                  ? isCompanyChatInternal
                                  : isInternalChatSelected)
                              ? 0
                              : 139,
                          child: Container(
                            height: 2,
                            width:
                                (isCompaniesSelected
                                    ? isCompanyChatInternal
                                    : isInternalChatSelected)
                                ? 112
                                : 95,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isCompaniesSelected = true;
                            });
                          },
                          child: Text(
                            'Компании',
                            style: TextStyle(
                              color: isCompaniesSelected
                                  ? accentColor
                                  : Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isCompaniesSelected = false;
                            });
                          },
                          child: Text(
                            'Юзеры',
                            style: TextStyle(
                              color: isCompaniesSelected
                                  ? Colors.white
                                  : accentColor,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Stack(
                      children: [
                        Container(
                          height: 1,
                          width: double.infinity,
                          color: Colors.white24,
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          left: isCompaniesSelected
                              ? 0
                              : 95, // Примерная позиция для вкладки "Юзеры"
                          child: Container(
                            height: 2,
                            width: isCompaniesSelected
                                ? 75
                                : 54, // Ширина подчеркивания
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Conditional rendering for message list or empty state
              messages.isEmpty
                  ? Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/messages/masseg.png',
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Нет сообщений',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'У вас нет сообщений, как только',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                Text(
                                  'вы получите его здесь оно будет',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                Text(
                                  'отображенно',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Expanded(
                      child: Column(
                        children: [
                          if (showCheckboxes)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CustomCheckbox(
                                    value: selectedMessages.values.every(
                                      (element) => element,
                                    ),
                                    onChanged: (bool newValue) {
                                      setState(() {
                                        // Get filtered messages based on current tabs
                                        final currentChatIsInternal =
                                            isCompaniesSelected
                                            ? isCompanyChatInternal
                                            : isInternalChatSelected;
                                        final filteredMessages = messages
                                            .where(
                                              (msg) =>
                                                  msg.isInternal ==
                                                      currentChatIsInternal &&
                                                  msg.isCompany ==
                                                      isCompaniesSelected,
                                            )
                                            .toList();

                                        // Get original indices of filtered messages
                                        final filteredIndices = filteredMessages
                                            .map((msg) => messages.indexOf(msg))
                                            .toList();

                                        // Select/deselect only filtered messages
                                        for (final index in filteredIndices) {
                                          selectedMessages[index] = newValue;
                                        }

                                        // Hide panel if all messages are deselected
                                        if (!newValue &&
                                            selectedMessages.values
                                                .where((v) => v)
                                                .isEmpty) {
                                          showCheckboxes = false;
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Выбрать все',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      final selectedIndices = selectedMessages
                                          .entries
                                          .where((entry) => entry.value)
                                          .map((entry) => entry.key)
                                          .toList();

                                      if (selectedIndices.isNotEmpty) {
                                        final selectedMessageMaps =
                                            selectedIndices.map((index) {
                                              final message = messages[index];
                                              return {
                                                'senderName':
                                                    message.senderName,
                                                'senderAvatar':
                                                    message.senderAvatar,
                                                'lastMessageTime':
                                                    message.lastMessageTime,
                                                'unreadCount':
                                                    message.unreadCount,
                                                'isInternal':
                                                    message.isInternal,
                                                'isCompany': message.isCompany,
                                              };
                                            }).toList();

                                        // Add to archive
                                        for (final messageMap
                                            in selectedMessageMaps) {
                                          await MessagesLocalService.addToArchive(
                                            messageMap,
                                          );
                                        }

                                        // Remove from currentMessages
                                        final currentMessages =
                                            MessagesLocalService.getCurrentMessages();
                                        currentMessages.removeWhere(
                                          (map) =>
                                              selectedMessageMaps.contains(map),
                                        );
                                        await MessagesLocalService.saveCurrentMessages(
                                          currentMessages,
                                        );

                                        setState(() {
                                          // Remove selected messages from the list
                                          selectedIndices.sort(
                                            (a, b) => b.compareTo(a),
                                          ); // Sort in descending order
                                          for (final index in selectedIndices) {
                                            messages.removeAt(index);
                                            selectedMessages.remove(index);
                                          }
                                          // Reindex selectedMessages
                                          final newSelected = <int, bool>{};
                                          for (
                                            int i = 0;
                                            i < messages.length;
                                            i++
                                          ) {
                                            newSelected[i] = false;
                                          }
                                          selectedMessages = newSelected;
                                          showCheckboxes = false;
                                        });
                                      }
                                    },
                                    child: const Text(
                                      'В архив',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 19,
                                    color: const Color(0xFF767676),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final selectedIndices = selectedMessages
                                          .entries
                                          .where((entry) => entry.value)
                                          .map((entry) => entry.key)
                                          .toList();

                                      if (selectedIndices.isNotEmpty) {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return DeleteChatDialog(
                                              onConfirm: () async {
                                                // Помечаем чат(ы) локально и отправляем запрос на сервер
                                                final nowIso = DateTime.now().toIso8601String();

                                                // Сортируем индексы по убыванию чтобы корректно удалять
                                                selectedIndices.sort((a, b) => b.compareTo(a));

                                                // Текущие сохранённые чаты
                                                final currentMessages = MessagesLocalService.getCurrentMessages();

                                                for (final index in selectedIndices) {
                                                  if (index < 0 || index >= messages.length) continue;
                                                  final msg = messages[index];

                                                  // Попытка удалить чат на сервере, если есть chatId
                                                  try {
                                                    if (msg.chatId != null) {
                                                      await ApiService.deleteChat(msg.chatId!);
                                                      log.d('✅ Chat ${msg.chatId} deleted on server');
                                                    }
                                                  } catch (e) {
                                                    log.d('⚠️ Failed to delete chat on server: $e');
                                                    // Продолжаем — пометим локально, чтобы скрыть чат
                                                  }

                                                  // Помечаем локально удаление (ключ — userId если есть, иначе chatId)
                                                  final idKey = msg.userId ?? (msg.chatId?.toString());
                                                  if (idKey != null) {
                                                    await MessagesLocalService.addDeletedChat(idKey, nowIso);
                                                  }

                                                  // Убираем из локального списка currentMessages
                                                  currentMessages.removeWhere((map) {
                                                    final mid = map['userId'] ?? map['chatId']?.toString();
                                                    return mid != null && idKey != null && mid.toString() == idKey.toString();
                                                  });
                                                }

                                                // Сохраняем обновлённый локальный список
                                                await MessagesLocalService.saveCurrentMessages(currentMessages);

                                                // Обновляем UI
                                                setState(() {
                                                  for (final index in selectedIndices) {
                                                    if (index >= 0 && index < messages.length) {
                                                      messages.removeAt(index);
                                                    }
                                                    selectedMessages.remove(index);
                                                  }

                                                  // Reindex selectedMessages
                                                  final newSelected = <int, bool>{};
                                                  for (int i = 0; i < messages.length; i++) {
                                                    newSelected[i] = false;
                                                  }
                                                  selectedMessages = newSelected;
                                                  showCheckboxes = false;
                                                });
                                              },
                                            );
                                          },
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.only(
                                        left: 10,
                                        right: 0,
                                        top: 0,
                                        bottom: 0,
                                      ),
                                    ),
                                    child: const Text(
                                      'Удалить',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final currentChatIsInternal =
                                    isCompaniesSelected
                                    ? isCompanyChatInternal
                                    : isInternalChatSelected;
                                final filteredMessages = messages
                                    .where(
                                      (msg) =>
                                          msg.isInternal ==
                                              currentChatIsInternal &&
                                          msg.isCompany == isCompaniesSelected,
                                    )
                                    .toList();
                                
                                // 📭 Если на вкладке нет сообщений
                                if (filteredMessages.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/messages/masseg.png',
                                          width: 100,
                                          height: 100,
                                          // opacity: const AlwaysStoppedAnimation(0.5),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Нет сообщений',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Text(
                                          'У вас нет сообщений, как только\nвы получите его здесь оно будет \nотображенно',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return ListView.builder(
                                  itemCount: filteredMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = filteredMessages[index];
                                    final originalIndex = messages.indexOf(
                                      message,
                                    );
                                    return MessageCard(
                                      message: message,
                                      isSelected:
                                          selectedMessages[originalIndex] ??
                                          false,
                                      onCheckboxChanged: (bool? newValue) {
                                        setState(() {
                                          selectedMessages[originalIndex] =
                                              newValue!;
                                          // Hide panel if all messages are deselected
                                          if (selectedMessages.values
                                              .where((v) => v)
                                              .isEmpty) {
                                            showCheckboxes = false;
                                          }
                                        });
                                      },
                                      onLongPress: () {
                                        setState(() {
                                          showCheckboxes = true;
                                          selectedMessages[originalIndex] =
                                              true;
                                        });
                                      },
                                      onTap: () {
                                        setState(() {
                                          showCheckboxes = false;
                                        });
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChatPage(message: message),
                                          ),
                                        );
                                      },
                                      showCheckboxes: showCheckboxes,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          onItemSelected: (index) {
            context.read<NavigationBloc>().add(
              SelectNavigationIndexEvent(index),
            );
          },
        ),
            ),
            );
          },
        ),
      );
    }
}
