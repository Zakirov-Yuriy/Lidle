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
import 'package:lidle/widgets/dialogs/delete_chat_dialog.dart';

class MessagesPage extends StatefulWidget {
  // Renamed from MessagesEmptyPage
  const MessagesPage({super.key});

  static const String routeName = '/messages';

  @override
  State<MessagesPage> createState() => _MessagesPageState(); // Renamed from _MessagesEmptyPageState
}

class _MessagesPageState extends State<MessagesPage> {
  bool isInternalChatSelected =
      true; // true для внутреннего чата, false для внешнего
  bool isCompaniesSelected = true; // true для компаний, false для юзеров
  bool isCompanyChatInternal =
      true; // true для внутреннего чата с компаниями, false для внешнего
  bool showCheckboxes = false; // Флаг для показа чекбоксов
  List<Message> messages = []; // Заполнитель для сообщений

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
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // Always use fresh dummy data to ensure isCompany field is present
    messages = dummyMessages;
    final messageMaps = dummyMessages
        .map(
          (msg) => {
            'senderName': msg.senderName,
            'senderAvatar': msg.senderAvatar,
            'lastMessageTime': msg.lastMessageTime,
            'unreadCount': msg.unreadCount,
            'isInternal': msg.isInternal,
            'isCompany': msg.isCompany,
          },
        )
        .toList();
    await HiveService.saveCurrentMessages(messageMaps);

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
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
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
                                          await HiveService.addToArchive(
                                            messageMap,
                                          );
                                        }

                                        // Remove from currentMessages
                                        final currentMessages =
                                            HiveService.getCurrentMessages();
                                        currentMessages.removeWhere(
                                          (map) =>
                                              selectedMessageMaps.contains(map),
                                        );
                                        await HiveService.saveCurrentMessages(
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
                                              onConfirm: () {
                                                setState(() {
                                                  // Remove selected messages from the list
                                                  selectedIndices.sort(
                                                    (a, b) => b.compareTo(a),
                                                  ); // Sort in descending order
                                                  for (final index
                                                      in selectedIndices) {
                                                    messages.removeAt(index);
                                                    selectedMessages.remove(
                                                      index,
                                                    );
                                                  }
                                                  // Reindex selectedMessages
                                                  final newSelected =
                                                      <int, bool>{};
                                                  for (
                                                    int i = 0;
                                                    i < messages.length;
                                                    i++
                                                  ) {
                                                    newSelected[i] = false;
                                                  }
                                                  selectedMessages =
                                                      newSelected;
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
  }
}
