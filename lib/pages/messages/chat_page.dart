import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/message_model.dart';
import 'package:lidle/models/chat_message_model.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/messages_local_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/pages/full_category_screen/property_details_screen.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'dart:async';

class ChatPage extends StatefulWidget {
  final Message message;
  final bool openedFromAdvertScreen;
  final Listing? initialListing; // ✅ Объявление для отправки как первое сообщение

  const ChatPage({
    super.key,
    required this.message,
    this.openedFromAdvertScreen = false,
    this.initialListing,
  });

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
  // Превью объявления, если доступно (показывается в верхнем блоке и в сообщении превью)
  String? _topAdvertTitle;
  String? _topAdvertImage;
  String? _topAdvertPrice;
  String? _topAdvertId;

  // 🛡️ Защита от параллельных запросов и rate limit
  bool _isLoadingMessagesBackground =
      false; // Флаг для предотвращения параллельных запросов
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
        print(
          '🔍 Ищем существующий чат для пользователя #${widget.message.userId}...',
        );
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
    // Убедимся, что если чат связан с объявлением, то превью объявления показано
    // 🔄 Запускаем таймер для автоматического обновления сообщений (каждые 2 сек)
    _startAutoUpdate();
  }

  /// Если чат связан с объявлением, но в списке сообщений нет данных об объявлении,
  /// пытаемся загрузить объявление из API и вставить превью в начало ленты.
  Future<void> _ensureAdvertPreviewPresent() async {
    // Удалена логика динамического добавления превью
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
          print(
            '📨 Получены новые сообщения: $newMessagesCount (было: $oldMessagesCount)',
          );
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
      if (e.toString().contains('429') ||
          e.toString().contains('RateLimitException')) {
        _rateLimitRetryCount++;
        // Экспоненциальная задержка: 30сек, 60сек, 120сек...
        final delaySeconds = 30 * (1 << (_rateLimitRetryCount - 1));
        print(
          '⏸️  Rate limit! Попытка $_rateLimitRetryCount. Ждем ${delaySeconds}сек перед повторной попыткой...',
        );

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
      final messages = await ApiService.getChatMessages(_chatId!);

      if (mounted) {
        // 🔄 Сортируем сообщения: старые вверху, новые внизу
        messages.sort((a, b) {
          final idA = a['id'] as int? ?? 0;
          final idB = b['id'] as int? ?? 0;
          return idA.compareTo(idB);
        });

        // ✅ Просто сохраняем сообщения как есть (без добавления превью)
        // Превью объявления будет добавлено при рендере если это необходимо
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // После загрузки сообщений — попробуем найти связанное объявление в сообщениях
        // и подгрузить его превью (чтобы получатель тоже видел, с какого объявления пришло сообщение)
        try {
          String? foundAdId;
          for (final m in messages) {
            if (m == null) continue;
            // Проверяем несколько возможных ключей
            if (m.containsKey('advertisementId') &&
                m['advertisementId'] != null) {
              foundAdId = m['advertisementId'].toString();
              break;
            }
            if (m.containsKey('advertisement_id') &&
                m['advertisement_id'] != null) {
              foundAdId = m['advertisement_id'].toString();
              break;
            }
            if (m.containsKey('advert_id') && m['advert_id'] != null) {
              foundAdId = m['advert_id'].toString();
              break;
            }
          }

          // Если нашли id объявления — подгрузим данные объявления
          if (foundAdId != null && foundAdId.isNotEmpty) {
            final adId = int.tryParse(foundAdId);
            if (adId != null) {
              final advert = await ApiService.getAdvert(adId);
              if (advert != null) {
                final image = advert.images.isNotEmpty
                    ? advert.images.first
                    : advert.thumbnail;
                if (mounted) {
                  setState(() {
                    _topAdvertTitle = advert.name;
                    _topAdvertPrice = advert.price;
                    _topAdvertImage = image;
                    _topAdvertId = advert.id.toString();
                  });
                }

                // Обновим локальный список чатов чтобы превью появилось в списке сообщений
                final current = MessagesLocalService.getCurrentMessages();
                final existingIndex = current.indexWhere(
                  (m) =>
                      m['userId'] == widget.message.userId &&
                      m['senderName'] == widget.message.senderName,
                );
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
                  'advertTitle': advert.name,
                  'advertImage': image,
                  'advertPrice': advert.price,
                  'advertisementId': advert.id.toString(),
                };
                if (existingIndex >= 0) {
                  current[existingIndex] = messageMap;
                } else {
                  current.insert(0, messageMap);
                }
                await MessagesLocalService.saveCurrentMessages(current);
              }
            }
          }
        } catch (e) {
          print(
            '⚠️ Ошибка при подгрузке превью объявления после загрузки сообщений: $e',
          );
        }

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
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      if (_chatId == null) return;

      // Находим все входящие сообщения которые еще не прочитаны
      final unreadIncomingMessages = messages.where((msg) {
        final isMe = msg['is_me'] as bool? ?? false;
        final readAt = msg['read_at'] as String?;
        return !isMe &&
            readAt == null; // От другого пользователя и не прочитано
      }).toList();

      if (unreadIncomingMessages.isEmpty) {
        print('✅ Нет непрочитанных входящих сообщений');
        return;
      }

      print(
        '📨 Отмечаем ${unreadIncomingMessages.length} сообщений как прочитанные...',
      );

      // Отмечаем каждое сообщение как прочитанное
      for (final msg in unreadIncomingMessages) {
        final messageId = msg['id'] as int?;
        if (messageId != null) {
          await ApiService.markMessageAsRead(_chatId!, messageId);
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
    final existingIndex = currentMessages.indexWhere(
      (msg) =>
          msg['senderName'] == widget.message.senderName &&
          msg['userId'] == widget.message.userId,
    );

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

        print(
          '💬 Начинаем новый чат с пользователем #${widget.message.userId}...',
        );
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

        await ApiService.sendMessage(chatId, messageText);
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
      return DateTime.now().toString().split(
        ' ',
      )[0]; // Возвращаем сегодня если нет даты
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
      final messageDateNormalized = DateTime(
        messageDate.year,
        messageDate.month,
        messageDate.day,
      );

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

            // Если чат открыт с экрана объявления, не показываем отдельную карточку сверху —
            // превью объявления будет показано как первое сообщение в ленте
            if (!widget.openedFromAdvertScreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    decoration: BoxDecoration(color: formBackground),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              (_topAdvertImage ?? widget.message.advertImage) !=
                                  null
                              ? ((_topAdvertImage ??
                                            widget.message.advertImage)!
                                        .startsWith('http')
                                    ? Image.network(
                                        (_topAdvertImage ??
                                            widget.message.advertImage)!,
                                        height: 66,
                                        width: 86,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFF374B5C),
                                                height: 66,
                                                width: 86,
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.white54,
                                                  size: 30,
                                                ),
                                              );
                                            },
                                      )
                                    : Image.asset(
                                        (_topAdvertImage ??
                                            widget.message.advertImage)!,
                                        height: 66,
                                        width: 86,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFF374B5C),
                                                height: 66,
                                                width: 86,
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.white54,
                                                  size: 30,
                                                ),
                                              );
                                            },
                                      ))
                              : Container(
                                  height: 66,
                                  width: 86,
                                  color: const Color(0xFF374B5C),
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // Показываем превью из состояния, если есть, иначе из переданного сообщения
                                _topAdvertTitle?.isNotEmpty == true
                                    ? _topAdvertTitle!
                                    : (widget.message.advertTitle?.isNotEmpty ==
                                              true
                                          ? widget.message.advertTitle!
                                          : '3-к. квартира, 125.5 м², 5/17 эт.'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_topAdvertPrice ?? widget.message.advertPrice ?? 'Цена не указана'} ₽',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () {
                                  // 🔗 Переход на объявление по ID с защитой от множественных тапов
                                  if (_isNavigatingToProperty ||
                                      (_topAdvertId == null &&
                                          widget.message.advertisementId ==
                                              null)) {
                                    return;
                                  }

                                  // Если чат был открыт с экрана объявления — просто возвращаемся назад
                                  if (widget.openedFromAdvertScreen &&
                                      Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                    return;
                                  }

                                  _isNavigatingToProperty = true;
                                  print(
                                    '🔗 Переходим на объявление #${_topAdvertId ?? widget.message.advertisementId}',
                                  );

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          PropertyDetailsScreen(
                                            advertisementId:
                                                _topAdvertId ??
                                                widget.message.advertisementId,
                                          ),
                                    ),
                                  ).then((_) {
                                    // ✅ Возвращаемся из PropertyDetailsScreen
                                    if (mounted) {
                                      print(
                                        '✅ Вернулись из PropertyDetailsScreen',
                                      );
                                      setState(() {
                                        _isNavigatingToProperty = false;
                                      });
                                    }
                                  });
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Перейти',
                                      style: TextStyle(
                                        color: const Color(0xFF00B7FF),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: const Color(0xFF00B7FF),
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // const SizedBox(height: 10),

            // Chat messages area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00B7FF),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        // Формируем список для отображения
                        final List<Map<String, dynamic>> messagesToDisplay =
                            List.from(_messages);
                        
                        // ✅ Если открыт с экрана объявления и передано объявление
                        // добавляем его как первое "сообщение" типа advert
                        if (widget.openedFromAdvertScreen && 
                            widget.initialListing != null &&
                            !messagesToDisplay.any((m) => m['is_advert_preview'] == true)) {
                          
                          final advertMessage = {
                            'id': -1,
                            'is_me': false,
                            'is_advert_preview': true,
                            'created_at': DateTime.now().toString(),
                            'message': '',
                            'advert': widget.initialListing, // ✅ Объект Listing
                          };
                          // Вставляем объявление в начало как первое сообщение
                          messagesToDisplay.insert(0, advertMessage);
                        }

                        if (messagesToDisplay.isEmpty) {
                          return Center(
                            child: Text(
                              'Нет сообщений',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          itemCount: messagesToDisplay.length,
                          itemBuilder: (context, index) {
                            final msg = messagesToDisplay[index];

                            // 📅 Проверяем показывать ли разделитель даты
                            bool showDateSeparator = true;
                            if (index > 0) {
                              final prevMsg = messagesToDisplay[index - 1];
                              final prevDate = _extractDate(
                                prevMsg['created_at'] as String?,
                              );
                              final currentDate = _extractDate(
                                msg['created_at'] as String?,
                              );
                              showDateSeparator = prevDate != currentDate;
                            }

                            return Column(
                              children: [
                                // 📅 Разделитель даты
                                if (showDateSeparator) ...[
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                    ),
                                    child: Text(
                                      _getDateLabel(
                                        msg['created_at'] as String?,
                                      ),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                // 💬 Если это превью объявления — показываем специальную карточку
                                if (msg['is_advert_preview'] == true) ...[
                                  const SizedBox(height: 8),
                                  _buildAdvertMessageCard(
                                    listing: msg['advert'] as Listing?,
                                    advertTitle: msg['advertTitle'] as String?,
                                    advertPrice: msg['advertPrice'] as String?,
                                    advertImage: msg['advertImage'] as String?,
                                    advertisementId: msg['advertisementId'] as String?,
                                  ),
                                  const SizedBox(height: 8),
                                ] else ...[
                                  // Обычное сообщение
                                  _buildMessageBubble(
                                    msg['message'] as String,
                                    isMe: msg['is_me'] as bool? ?? false,
                                    createdAt: msg['created_at'] as String?,
                                  ),
                                ]
                              ],
                            );
                          },
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
                              // Разрешаем многострочный ввод: Enter добавляет новую строку
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              minLines: 1,
                              maxLines: 6,
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
        ? activeIconColor // Синий для моих сообщений
        : formBackground; // Темный для чужих

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

  /// 🎖️ Карточка с объявлением как сообщение (для отправки объявления как первого сообщения)
  Widget _buildAdvertMessageCard({
    Listing? listing,
    String? advertTitle,
    String? advertPrice,
    String? advertImage,
    String? advertisementId,
  }) {
    // Если передано объявление как объект, используем его, иначе используем переданные параметры
    final title = listing?.title ?? advertTitle ?? 'Объявление';
    final price = listing?.price ?? advertPrice ?? 'Цена не указана';
    final image = listing?.images.isNotEmpty == true
        ? listing!.images.first
        : (listing?.imagePath ?? advertImage);
    final adId = listing?.id ?? advertisementId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (_isNavigatingToProperty || adId == null) return;

            _isNavigatingToProperty = true;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => listing != null
                    ? MiniPropertyDetailsScreen(listing: listing)
                    : PropertyDetailsScreen(advertisementId: adId),
              ),
            ).then((_) {
              if (mounted) {
                setState(() {
                  _isNavigatingToProperty = false;
                });
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Row(
              children: [
                // 📸 Изображение
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: image != null
                      ? (image.startsWith('http')
                          ? Image.network(
                              image,
                              height: 70,
                              width: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFF374B5C),
                                  height: 70,
                                  width: 70,
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                );
                              },
                            )
                          : Image.asset(
                              image,
                              height: 70,
                              width: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFF374B5C),
                                  height: 70,
                                  width: 70,
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                );
                              },
                            ))
                      : Container(
                          height: 70,
                          width: 70,
                          color: const Color(0xFF374B5C),
                          child: const Icon(
                            Icons.image,
                            color: Colors.white54,
                            size: 30,
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // 📝 Информация об объявлении
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$price ₽',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Text(
                            'Подробнее',
                            style: TextStyle(
                              color: activeIconColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: activeIconColor,
                            size: 11,
                          ),
                        ],
                      ),
                    ],
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
