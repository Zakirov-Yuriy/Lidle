import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/message_model.dart';
import 'package:lidle/widgets/cards/message_card.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/hive_service.dart';

class MessagesArchivePage extends StatefulWidget {
  const MessagesArchivePage({super.key});

  static const String routeName = '/messages-archive';

  @override
  State<MessagesArchivePage> createState() => _MessagesArchivePageState();
}

class _MessagesArchivePageState extends State<MessagesArchivePage> {
  bool isInternalChatSelected = true; // true для внутреннего чата, false для внешнего
  bool showCheckboxes = false; // Флаг для показа чекбоксов
  List<Map<String, dynamic>> archivedMessages = [];
  Map<int, bool> selectedMessages = {};

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

  @override
  void initState() {
    super.initState();
    _loadArchivedMessages();
  }

  Future<void> _loadArchivedMessages() async {
    final messages = HiveService.getArchivedMessages();
    setState(() {
      archivedMessages = messages;
      selectedMessages = {};
      for (int i = 0; i < archivedMessages.length; i++) {
        selectedMessages[i] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 25, right: 23),
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
                      
                    ],
                  ),
                ),


            

            const SizedBox(height: 12),

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
                            color: isInternalChatSelected ? accentColor : Colors.white,
                            fontSize: 14,
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
                            color: isInternalChatSelected ? Colors.white : accentColor,
                            fontSize: 14,
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
                        left: isInternalChatSelected ? 0 : 125, // Примерная позиция для второй вкладки
                        child: Container(
                          height: 2,
                          width: 105, // Ширина подчеркивания
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Conditional rendering for archived messages list or empty state
            archivedMessages.isEmpty
                ? Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/messages/non.png', width: 120, height: 120),
                        const SizedBox(height: 16),
                        const Text(
                          'Нет сообщений в архиве',
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
                                'Архив пуст',
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
                                    selectedMessages.updateAll((key, value) => newValue);
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
                                    for (final index in selectedIndices) {
                                      await HiveService.restoreFromArchive(index);
                                    }
                                    await _loadArchivedMessages();
                                    Navigator.pop(context, true);
                                  }
                                },
                                child: const Text(
                                  'Вернуть из архива',
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
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                            itemCount: archivedMessages.length,
                            itemBuilder: (context, index) {
                              final messageMap = archivedMessages[index];
                              final message = Message(
                                senderName: messageMap['senderName'],
                                senderAvatar: messageMap['senderAvatar'],
                                lastMessageTime: messageMap['lastMessageTime'],
                                unreadCount: messageMap['unreadCount'],
                                isInternal: messageMap['isInternal'] ?? true,
                              );
                              return MessageCard(
                                message: message,
                                isSelected: selectedMessages[index] ?? false,
                                onCheckboxChanged: (bool? newValue) {
                                  setState(() {
                                    selectedMessages[index] = newValue!;
                                  });
                                },
                                onTap: () {},
                                showCheckboxes: showCheckboxes,
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
    );
  }
}
