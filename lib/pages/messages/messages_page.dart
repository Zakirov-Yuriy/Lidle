import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/message_model.dart'; // Import Message model
import 'package:lidle/widgets/cards/message_card.dart'; // Import MessageCard
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/pages/messages/chat_page.dart';
import 'package:lidle/hive_service.dart';

class MessagesPage extends StatefulWidget { // Renamed from MessagesEmptyPage
  const MessagesPage({super.key});

  static const String routeName = '/messages';

  @override
  State<MessagesPage> createState() => _MessagesPageState(); // Renamed from _MessagesEmptyPageState
}

class _MessagesPageState extends State<MessagesPage> {
  bool isInternalChatSelected = true; // true для внутреннего чата, false для внешнего
  bool showCheckboxes = false; // Флаг для показа чекбоксов
  List<Message> messages = []; // Placeholder for messages

  // Dummy data for messages
  List<Message> dummyMessages = [
    Message(
      senderName: 'Виталий Покрышкин',
      senderAvatar: 'assets/profile_dashboard/Ellipse.png', // Assuming this asset exists
      lastMessageTime: 'был(а) сегодня',
      unreadCount: 4,
      isInternal: true,
    ),
    Message(
      senderName: 'Данил',
      senderAvatar: null,
      lastMessageTime: 'был(а) 5 августа',
      unreadCount: 3,
      isInternal: false,
    ),
    Message(
      senderName: 'Григорий Цех',
      senderAvatar: null,
      lastMessageTime: 'был(а) сегодня',
      unreadCount: 15,
      isInternal: true,
    ),
    Message(
      senderName: 'Данил',
      senderAvatar: null,
      lastMessageTime: 'был(а) недавно',
      unreadCount: 1,
      isInternal: false,
    ),
    Message(
      senderName: 'Данил',
      senderAvatar: null,
      lastMessageTime: 'был(а) недавно',
      unreadCount: 2,
      isInternal: true,
    ),
  ];

  // Keep track of selected messages for deletion/archive
  Map<int, bool> selectedMessages = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final currentMessages = HiveService.getCurrentMessages();
    if (currentMessages.isEmpty) {
      // If no current messages, use dummy and save
      messages = dummyMessages;
      final messageMaps = dummyMessages.map((msg) => {
        'senderName': msg.senderName,
        'senderAvatar': msg.senderAvatar,
        'lastMessageTime': msg.lastMessageTime,
        'unreadCount': msg.unreadCount,
        'isInternal': msg.isInternal,
      }).toList();
      await HiveService.saveCurrentMessages(messageMaps);
    } else {
      messages = currentMessages.map((map) => Message(
        senderName: map['senderName'],
        senderAvatar: map['senderAvatar'],
        lastMessageTime: map['lastMessageTime'],
        unreadCount: map['unreadCount'],
        isInternal: map['isInternal'] ?? true,
      )).toList();
    }
    for (int i = 0; i < messages.length; i++) {
      selectedMessages[i] = false;
    }
    setState(() {});
  }

  static const accentColor = Color(0xFF00B7FF);

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile || state is NavigationToHome || state is NavigationToFavorites || state is NavigationToAddListing || state is NavigationToMyPurchases) {
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
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: activeIconColor,
                      size: 16,
                    ),
                  ),
                  const Text(
                    'Назад',
                    style: TextStyle(
                      color: activeIconColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(context, '/messages-archive');
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
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isInternalChatSelected = true;
                          });
                        },
                        child: Text(
                          'Внутренний чат',
                          style: TextStyle(
                            color: isInternalChatSelected
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
                            isInternalChatSelected = false;
                          });
                        },
                        child: Text(
                          'Внешний чат',
                          style: TextStyle(
                            color: isInternalChatSelected
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
                        left: isInternalChatSelected
                            ? 0
                            : 135, // Примерная позиция для второй вкладки
                        child: Container(
                          height: 2,
                          width: 109, // Ширина подчеркивания
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                          child: Row(
                            children: [
                              CustomCheckbox(
                                value: selectedMessages.values.every((element) => element),
                                onChanged: (bool newValue) {
                                  setState(() {
                                    selectedMessages.updateAll((key, value) => newValue); // Select/deselect all
                                    if (showCheckboxes && selectedMessages.values.where((v) => v).isEmpty) {
                                      showCheckboxes = false; // Скрыть чекбоксы если нет выбранных
                                    } else {
                                      showCheckboxes = true; // Показать чекбоксы
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Выбрать все',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () async {
                                  setState(() {
                                    if (showCheckboxes && selectedMessages.values.where((v) => v).isEmpty) {
                                      showCheckboxes = false; // Скрыть чекбоксы если нет выбранных
                                    } else {
                                      showCheckboxes = true; // Показать чекбоксы
                                    }
                                  });
                                  final selectedIndices = selectedMessages.entries
                                      .where((entry) => entry.value)
                                      .map((entry) => entry.key)
                                      .toList();

                                  if (selectedIndices.isNotEmpty) {
                                    final selectedMessageMaps = selectedIndices.map((index) {
                                      final message = messages[index];
                                      return {
                                        'senderName': message.senderName,
                                        'senderAvatar': message.senderAvatar,
                                        'lastMessageTime': message.lastMessageTime,
                                        'unreadCount': message.unreadCount,
                                        'isInternal': message.isInternal,
                                      };
                                    }).toList();

                                    // Add to archive
                                    for (final messageMap in selectedMessageMaps) {
                                      await HiveService.addToArchive(messageMap);
                                    }

                                    // Remove from currentMessages
                                    final currentMessages = HiveService.getCurrentMessages();
                                    currentMessages.removeWhere((map) => selectedMessageMaps.contains(map));
                                    await HiveService.saveCurrentMessages(currentMessages);

                                    setState(() {
                                      // Remove selected messages from the list
                                      selectedIndices.sort((a, b) => b.compareTo(a)); // Sort in descending order
                                      for (final index in selectedIndices) {
                                        messages.removeAt(index);
                                        selectedMessages.remove(index);
                                      }
                                      // Reindex selectedMessages
                                      final newSelected = <int, bool>{};
                                      for (int i = 0; i < messages.length; i++) {
                                        newSelected[i] = false;
                                      }
                                      selectedMessages = newSelected;
                                    });
                                  }
                                },
                                child: const Text(
                                  'В архив',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 14,
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
                              final filteredMessages = messages.where((msg) => msg.isInternal == isInternalChatSelected).toList();
                              return ListView.builder(
                                itemCount: filteredMessages.length,
                                itemBuilder: (context, index) {
                                  final message = filteredMessages[index];
                                  final originalIndex = messages.indexOf(message);
                                  return MessageCard(
                                    message: message,
                                    isSelected: selectedMessages[originalIndex] ?? false,
                                    onCheckboxChanged: (bool? newValue) {
                                      setState(() {
                                        selectedMessages[originalIndex] = newValue!;
                                      });
                                    },
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatPage(message: message),
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
          context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
        },
      ),
      ),
    );
  }
}
