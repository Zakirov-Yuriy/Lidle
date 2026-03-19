import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/message_model.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/messages_local_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/pages/full_category_screen/property_details_screen.dart';
import 'dart:async';

class ChatPage extends StatefulWidget {
  final Message message;

  const ChatPage({super.key, required this.message});

  static const String routeName = '/chat';

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _updateTimer; // 🔄 Таймер для автоматического обновления сообщений
  late int? _chatId; // 💾 ID чата (может быть получен из startChat)
  
  // 🛡️ Защита от параллельных запросов и rate limit
  bool _isLoadingMessagesBackground = false; // Флаг для предотвращения параллельных запросов
  int _rateLimitRetryCount = 0; // Счетчик попыток при rate limit
  Timer? _rateLimitTimer; // Таймер для восстановления после rate limit
  
  // 🔗 Защита от множественных нажатий на "Перейти"
  bool _isNavigatingToProperty = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _chatId = widget.message.chatId; // Инициализируем из message
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _updateTimer?.cancel(); // 🔴 Отменяем таймер при закрытии экрана
    _rateLimitTimer?.cancel(); // 🔴 Отменяем таймер rate limit
    super.dispose();
  }

  /// 💬 Прокрутить вниз к последнему сообщению
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 💬 Инициализировать чат: сохранить, загрузить сообщения и запустить обновление
  Future<void> _initializeChat() async {
    // 🔄 Если chatId не передан, пытаемся найти существующий чат по userId
    if (_chatId == null && widget.message.userId != null) {
      try {
        print('🔍 Ищем существующий чат для пользователя #${widget.message.userId}...');
        final chats = await ApiService.getChats();
        final userId = int.tryParse(widget.message.userId!);
        
        // 🔍 Ищем чат с этим пользователем
        for (final chat in chats) {
          final userData = chat['user'] as Map<String, dynamic>?;
          if (userData != null && userData['id'] == userId) {
            _chatId = chat['id'] as int?;
            print('✅ Найден существующий чат с ID #$_chatId');
            break;
          }
        }
      } catch (e) {
        print('⚠️ Ошибка при поиске существующего чата: $e');
      }
    }

    await _saveChat();
    await _loadMessages();
    // 🔄 Запускаем таймер для автоматического обновления сообщений (каждые 2 сек)
    _startAutoUpdate();
  }

  /// 🔄 Запустить периодическое обновление сообщений
  void _startAutoUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _chatId != null) {
        // Загружаем новые сообщения без показа лоадера
        _loadMessagesBackground();
      }
    });
    print('✅ Таймер обновления сообщений запущен (интервал 15 сек)');
  }

  /// 💬 Загрузить сообщения в фоне (без показа лоадера)
  /// 🛡️ С защитой от параллельных запросов и rate limiting
  Future<void> _loadMessagesBackground() async {
    // 🛡️ Пропускаем если уже загружаются сообщения
    if (_isLoadingMessagesBackground) {
      print('⏭️  Пропускаем загрузку (уже идет загрузка сообщений)');
      return;
    }

    try {
      if (_chatId == null) return;

      _isLoadingMessagesBackground = true;
      final messages = await ApiService.getChatMessages(_chatId!);

      if (mounted) {
        // Сортируем по ID в возрастающем порядке
        messages.sort((a, b) {
          final idA = a['id'] as int? ?? 0;
          final idB = b['id'] as int? ?? 0;
          return idA.compareTo(idB);
        });

        // Проверяем есть ли новые сообщения
        final newMessagesCount = messages.length;
        final oldMessagesCount = _messages.length;

        // Если появились новые сообщения - обновляем и прокручиваем вниз
        if (newMessagesCount > oldMessagesCount) {
          print('📨 Получены новые сообщения: $newMessagesCount (было: $oldMessagesCount)');
          setState(() {
            _messages = messages;
          });
          // Автоскролл вниз при появлении новых сообщений
          _scrollToBottom();
        }
        
        // 🛡️ Сброс счетчика попыток при успехе
        _rateLimitRetryCount = 0;
      }
    } catch (e) {
      // 🛡️ Обработка Rate Limit (429 Too Many Requests)
      if (e.toString().contains('429') || e.toString().contains('RateLimitException')) {
        _rateLimitRetryCount++;
        // Экспоненциальная задержка: 30сек, 60сек, 120сек...
        final delaySeconds = 30 * (1 << (_rateLimitRetryCount - 1));
        print('⏸️  Rate limit! Попытка $_rateLimitRetryCount. Ждем ${delaySeconds}сек перед повторной попыткой...');
        
        // Отменяем текущий таймер
        _updateTimer?.cancel();
        
        // Запускаем новый таймер через задержку
        _rateLimitTimer = Timer(Duration(seconds: delaySeconds), () {
          if (mounted) {
            print('🔄 Восстанавливаем периодическое обновление сообщений');
            _startAutoUpdate();
          }
        });
      } else {
        print('⚠️  Ошибка фонового обновления: $e');
        _rateLimitRetryCount = 0;
      }
    } finally {
      _isLoadingMessagesBackground = false;
    }
  }

  /// 💬 Загрузить сообщения из API
  Future<void> _loadMessages() async {
    try {
      if (_chatId == null) {
        print('⚠️ Chat ID not available, cannot load messages');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('📥 Загружаем сообщения чата #$_chatId...');
      final messages = await ApiService.getChatMessages(
        _chatId!,
      );

      if (mounted) {
        // 🔄 Сортируем сообщения: старые вверху, новые внизу
        // Сортируем по ID в возрастающем порядке (старые имеют меньший ID)
        messages.sort((a, b) {
          final idA = a['id'] as int? ?? 0;
          final idB = b['id'] as int? ?? 0;
          return idA.compareTo(idB);
        });

        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // ✅ Отмечаем все входящие сообщения как прочитанные
        _markIncomingMessagesAsRead(messages);
        
        // Прокручиваем вниз к последнему сообщению
        _scrollToBottom();
      }
    } catch (e) {
      print('❌ Ошибка загрузки сообщений: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ✅ Отметить все входящие сообщения как прочитанные
  Future<void> _markIncomingMessagesAsRead(
      List<Map<String, dynamic>> messages) async {
    try {
      if (_chatId == null) return;

      // Находим все входящие сообщения которые еще не прочитаны
      final unreadIncomingMessages = messages.where((msg) {
        final isMe = msg['is_me'] as bool? ?? false;
        final readAt = msg['read_at'] as String?;
        return !isMe && readAt == null; // От другого пользователя и не прочитано
      }).toList();

      if (unreadIncomingMessages.isEmpty) {
        print('✅ Нет непрочитанных входящих сообщений');
        return;
      }

      print('📨 Отмечаем ${unreadIncomingMessages.length} сообщений как прочитанные...');

      // Отмечаем каждое сообщение как прочитанное
      for (final msg in unreadIncomingMessages) {
        final messageId = msg['id'] as int?;
        if (messageId != null) {
          await ApiService.markMessageAsRead(
            _chatId!,
            messageId,
          );
        }
      }

      print('✅ Все входящие сообщения отмечены как прочитанные');
    } catch (e) {
      print('⚠️ Ошибка при отметке сообщений как прочитанных: $e');
      // Не критично если это не сработает
    }
  }

  /// 💬 Сохранить чат в локальное хранилище
  Future<void> _saveChat() async {
    final messageMap = {
      'senderName': widget.message.senderName,
      'senderAvatar': widget.message.senderAvatar,
      'lastMessageTime': 'сейчас',
      'unreadCount': 0,
      'isInternal': widget.message.isInternal,
      'isCompany': widget.message.isCompany,
      'userId': widget.message.userId,
      'chatId': _chatId,
      'lastMessage': widget.message.lastMessage,
      'advertTitle': widget.message.advertTitle,
      'advertImage': widget.message.advertImage,
      'advertPrice': widget.message.advertPrice,
      'advertisementId': widget.message.advertisementId,
    };

    // Загружаем текущие сообщения
    final currentMessages = MessagesLocalService.getCurrentMessages();
    
    // Проверяем, есть ли уже такой чат
    final existingIndex = currentMessages.indexWhere((msg) =>
        msg['senderName'] == widget.message.senderName &&
        msg['userId'] == widget.message.userId);
    
    if (existingIndex >= 0) {
      // Обновляем существующий чат
      currentMessages[existingIndex] = messageMap;
    } else {
      // Добавляем новый чат
      currentMessages.insert(0, messageMap);
    }
    
    // Сохраняем в локальное хранилище
    await MessagesLocalService.saveCurrentMessages(currentMessages);
  }

  /// 💬 Отправить сообщение через API
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final messageText = _messageController.text;
    _messageController.clear();

    try {
      int? chatId = _chatId;

      // 🔄 Если это новый чат (нет chatId), создаём его через startChat()
      if (chatId == null) {
        if (widget.message.userId == null) {
          throw Exception('Информация о продавце недоступна');
        }

        print('💬 Начинаем новый чат с пользователем #${widget.message.userId}...');
        chatId = await ApiService.startChat(
          int.parse(widget.message.userId!),
          messageText,
        );

        // 🔄 Если чат не создан (возможно уже существует), ищем его в списке
        if (chatId == null) {
          print('⚠️ chatId null, пытаемся найти существующий чат...');
          final chats = await ApiService.getChats();
          final userId = int.tryParse(widget.message.userId!);
          
          // 🔍 Ищем чат с этим пользователем
          for (final chat in chats) {
            final userData = chat['user'] as Map<String, dynamic>?;
            if (userData != null && userData['id'] == userId) {
              chatId = chat['id'] as int?;
              print('✅ Найден существующий чат с ID #$chatId');
              break;
            }
          }
        }

        if (chatId == null) {
          throw Exception('Не удалось создать или найти чат');
        }

        print('✅ Будет использован чат с ID #$chatId');
        // 💾 Сохраняем полученный chatId в состояние
        setState(() {
          _chatId = chatId;
        });
      } else {
        // ✅ Обычная отправка сообщения в существующий чат
        print('📤 Отправляем сообщение в чат #$chatId...');
        
        await ApiService.sendMessage(
          chatId,
          messageText,
        );
      }

      // Перезагружаем сообщения чтобы показать новое
      await _loadMessages();
      // Прокручиваем вниз к новому сообщению
      _scrollToBottom();
    } catch (e) {
      print('❌ Ошибка отправки сообщения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 📅 Вытянуть дату из created_at в формате "yyyy-MM-dd"
  String _extractDate(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) {
      return DateTime.now().toString().split(' ')[0]; // Возвращаем сегодня если нет даты
    }
    
    try {
      // Ожидаем формат "15.03.2026 18:32:17" или "2026-03-15T18:32:17"
      DateTime dateTime;
      
      if (createdAt.contains('.')) {
        // Формат "15.03.2026 18:32:17"
        final parts = createdAt.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('.');
          if (dateParts.length == 3) {
            dateTime = DateTime(
              int.parse(dateParts[2]), // год
              int.parse(dateParts[1]), // месяц
              int.parse(dateParts[0]), // день
            );
          } else {
            dateTime = DateTime.now();
          }
        } else {
          dateTime = DateTime.now();
        }
      } else if (createdAt.contains('-') && createdAt.contains('T')) {
        // Формат ISO "2026-03-15T18:32:17"
        dateTime = DateTime.parse(createdAt);
      } else {
        dateTime = DateTime.now();
      }
      
      // Возвращаем дату в формате "yyyy-MM-dd"
      return dateTime.toString().split(' ')[0];
    } catch (e) {
      print('⚠️ Ошибка парсирования даты: $e');
      return DateTime.now().toString().split(' ')[0];
    }
  }

  /// 📅 Получить лейбл даты (Сегодня, Вчера, или дата)
  String _getDateLabel(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) {
      return 'Сегодня';
    }
    
    try {
      // Парсируем дату из создания сообщения
      DateTime messageDate;
      
      if (createdAt.contains('.')) {
        // Формат "15.03.2026 18:32:17"
        final parts = createdAt.split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('.');
          if (dateParts.length == 3) {
            messageDate = DateTime(
              int.parse(dateParts[2]), // год
              int.parse(dateParts[1]), // месяц
              int.parse(dateParts[0]), // день
            );
          } else {
            return 'Сегодня';
          }
        } else {
          return 'Сегодня';
        }
      } else if (createdAt.contains('-') && createdAt.contains('T')) {
        // Формат ISO "2026-03-15T18:32:17"
        messageDate = DateTime.parse(createdAt);
      } else {
        return 'Сегодня';
      }
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDateNormalized = DateTime(messageDate.year, messageDate.month, messageDate.day);
      
      // Сравниваем даты
      if (messageDateNormalized == today) {
        return 'Сегодня';
      } else if (messageDateNormalized == yesterday) {
        return 'Вчера';
      } else {
        // Форматируем дату в "d MMMM" (например "15 марта")
        // Используем русский формат
        final dayMonth = messageDate.day;
        final monthName = _getMonthName(messageDate.month);
        return '$dayMonth $monthName';
      }
    } catch (e) {
      print('⚠️ Ошибка форматирования даты: $e');
      return 'Сегодня';
    }
  }

  /// 📅 Получить название месяца на русском
  String _getMonthName(int month) {
    const monthNames = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    
    if (month >= 1 && month <= 12) {
      return monthNames[month - 1];
    }
    return 'неизвестный месяц';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Logo Header
            const Header(),

            const SizedBox(height: 20),

            // User chat header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_back_ios,
                          color: activeIconColor,
                          size: 16,
                        ),
                        const SizedBox(
                          width: 4,
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
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 25, right: 7),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white10,
                    backgroundImage: widget.message.senderAvatar != null
                        ? (widget.message.senderAvatar!.startsWith('http')
                            ? NetworkImage(widget.message.senderAvatar!)
                            : AssetImage(widget.message.senderAvatar!))
                        : null,
                    child: widget.message.senderAvatar == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 28,
                          )
                        : null,
                  ),
                ),

                // const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.senderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'был(а) недавно', // Заполнитель статуса
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: const Divider(color: Color(0xFF474747), height: 0),
            ),

            // User's announcement времмено закоментируем  табличку с обьявлением 
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 25),
            //   child: ClipRRect(
            //     borderRadius: BorderRadius.circular(3),
            //     child: Container(
            //       decoration: BoxDecoration(color: formBackground),
            //       padding: const EdgeInsets.all(12),
            //       child: Row(
            //         children: [
            //           // Image
            //           ClipRRect(
            //             borderRadius: BorderRadius.circular(8),
            //             child: widget.message.advertImage != null
            //                 ? (widget.message.advertImage!.startsWith('http')
            //                     ? Image.network(
            //                         widget.message.advertImage!,
            //                         height: 66,
            //                         width: 86,
            //                         fit: BoxFit.cover,
            //                         errorBuilder:
            //                             (context, error, stackTrace) {
            //                           return Container(
            //                             color: const Color(0xFF374B5C),
            //                             height: 66,
            //                             width: 86,
            //                             child: const Icon(Icons.image,
            //                                 color: Colors.white54, size: 30),
            //                           );
            //                         },
            //                       )
            //                     : Image.asset(
            //                         widget.message.advertImage!,
            //                         height: 66,
            //                         width: 86,
            //                         fit: BoxFit.cover,
            //                         errorBuilder:
            //                             (context, error, stackTrace) {
            //                           return Container(
            //                             color: const Color(0xFF374B5C),
            //                             height: 66,
            //                             width: 86,
            //                             child: const Icon(Icons.image,
            //                                 color: Colors.white54, size: 30),
            //                           );
            //                         },
            //                       ))
            //                 : Container(
            //                     height: 66,
            //                     width: 86,
            //                     color: const Color(0xFF374B5C),
            //                     child: const Icon(Icons.image,
            //                         color: Colors.white54, size: 30),
            //                   ),
            //           ),
            //           const SizedBox(width: 12),
            //           // Content
            //           Expanded(
            //             child: Column(
            //               crossAxisAlignment: CrossAxisAlignment.start,
            //               children: [
            //                 Text(
            //                   widget.message.advertTitle
            //                           ?.isNotEmpty ==
            //                       true
            //                       ? widget.message.advertTitle!
            //                       : '3-к. квартира, 125.5 м², 5/17 эт.',
            //                   style: const TextStyle(
            //                     color: Colors.white,
            //                     fontSize: 15,
            //                     fontWeight: FontWeight.w600,
            //                     height: 1.3,
            //                   ),
            //                   maxLines: 2,
            //                   overflow: TextOverflow.ellipsis,
            //                 ),
            //                 const SizedBox(height: 2),
            //                 Text(
            //                   '${widget.message.advertPrice ?? 'Цена не указана'} ₽',
            //                   style: const TextStyle(
            //                     color: Color.fromARGB(255, 255, 255, 255),
            //                     fontSize: 16,
            //                     fontWeight: FontWeight.w700,
            //                   ),
            //                 ),
            //                 const SizedBox(height: 2),
            //                 GestureDetector(
            //                   onTap: () {
            //                     // 🔗 Переход на объявление по ID с защитой от множественных тапов
            //                     if (_isNavigatingToProperty || widget.message.advertisementId == null) {
            //                       return;
            //                     }
                                
            //                     _isNavigatingToProperty = true;
            //                     print('🔗 Переходим на объявление #${widget.message.advertisementId}');
                                
            //                     Navigator.push(
            //                       context,
            //                       MaterialPageRoute(
            //                         builder: (context) => PropertyDetailsScreen(
            //                           advertisementId: widget.message.advertisementId,
            //                         ),
            //                       ),
            //                     ).then((_) {
            //                       // ✅ Возвращаемся из PropertyDetailsScreen
            //                       if (mounted) {
            //                         print('✅ Вернулись из PropertyDetailsScreen');
            //                         setState(() {
            //                           _isNavigatingToProperty = false;
            //                         });
            //                       }
            //                     });
            //                   },
            //                   child: Row(
            //                     mainAxisSize: MainAxisSize.min,
            //                     children: [
            //                       const Text(
            //                         'Перейти',
            //                         style: TextStyle(
            //                           color: const Color(0xFF00B7FF),
            //                           fontSize: 14,
            //                           fontWeight: FontWeight.w600,
            //                         ),
            //                       ),
            //                       const SizedBox(width: 4),
            //                       Icon(
            //                         Icons.arrow_forward_ios,
            //                         color: const Color(0xFF00B7FF),
            //                         size: 14,
            //                       ),
            //                     ],
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // ),

            // const SizedBox(height: 10),

            // Chat messages area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00B7FF),
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Нет сообщений',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 25),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            
                            // 📅 Проверяем показывать ли разделитель даты
                            bool showDateSeparator = true;
                            if (index > 0) {
                              final prevMsg = _messages[index - 1];
                              final prevDate = _extractDate(prevMsg['created_at'] as String?);
                              final currentDate = _extractDate(msg['created_at'] as String?);
                              showDateSeparator = prevDate != currentDate;
                            }

                            return Column(
                              children: [
                                // 📅 Разделитель даты
                                if (showDateSeparator) ...[
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 0),
                                    child: Text(
                                      _getDateLabel(msg['created_at'] as String?),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                
                                // 💬 Сообщение
                                _buildMessageBubble(
                                  msg['message'] as String,
                                  isMe: msg['is_me'] as bool? ?? false,
                                  createdAt: msg['created_at'] as String?,
                                ),
                              ],
                            );
                          },
                        ),
            ),

            // Message input
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 16, bottom: 16),
              child: Row(
                children: [
                  // const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: formBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Сообщение',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: GestureDetector(
                              onTap: _sendMessage,
                              child: SvgPicture.asset(
                                'assets/chat_page/send-03.svg',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    String text, {
    required bool isMe,
    String? createdAt,
  }) {
    // Парсим время из createdAt если оно есть
    String timeDisplay = '20:21';
    if (createdAt != null && createdAt.isNotEmpty) {
      try {
        // Ожидаем формат "15.03.2026 18:32:17"
        final parts = createdAt.split(' ');
        if (parts.length >= 2) {
          final timeParts = parts[1].split(':');
          if (timeParts.length >= 2) {
            timeDisplay = '${timeParts[0]}:${timeParts[1]}';
          }
        }
      } catch (e) {
        print('❌ Error parsing time: $e');
      }
    }

    // Цвет сообщения зависит от того кто его отправил
    final bubbleColor = isMe 
        ? activeIconColor  // Синий для моих сообщений
        : formBackground;  // Темный для чужих
    
    final textColor = Colors.white;

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 45),
                  child: Text(
                    text,
                    style: TextStyle(color: textColor, fontSize: 15),
                    softWrap: true,
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 1,
                  child: Text(
                    timeDisplay,
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
