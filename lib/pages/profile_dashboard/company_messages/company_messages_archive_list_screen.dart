import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/profile_dashboard/user_messages/user_messages_archive_list_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/pages/profile_dashboard/user_messages/chat_page.dart';
import 'package:lidle/pages/profile_dashboard/company_messages/company_messages_list_screen.dart';
import 'package:lidle/blocs/company_messages/company_messages_bloc.dart';
import 'package:lidle/blocs/company_messages/company_messages_state.dart';
import 'package:lidle/blocs/company_messages/company_messages_event.dart';

class CompanyMessagesArchiveListScreen extends StatefulWidget {
  const CompanyMessagesArchiveListScreen({super.key});

  static const String routeName = '/company-messages-archive-list';

  static const backgroundColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const unreadBorder = Color(0xFF3A4A5A);

  @override
  State<CompanyMessagesArchiveListScreen> createState() =>
      _CompanyMessagesArchiveListScreenState();
}

class _CompanyMessagesArchiveListScreenState
    extends State<CompanyMessagesArchiveListScreen> {
  bool isMainSelected = false; // true для основных, false для архива
  bool selectAll = false;
  List<bool> selectedItems = [];

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToAddListing ||
            state is NavigationToMyPurchases ||
            state is NavigationToMessages ||
            state is NavigationToSignIn) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: BlocBuilder<CompanyMessagesBloc, CompanyMessagesState>(
        builder: (context, messagesState) {
          if (messagesState is CompanyMessagesLoaded) {
            final archivedMessages = messagesState.archivedMessages;
            if (selectedItems.length != archivedMessages.length) {
              selectedItems = List.filled(archivedMessages.length, false);
              selectAll = false;
            }
            return BlocBuilder<NavigationBloc, NavigationState>(
              builder: (context, navigationState) {
                return Scaffold(
                  extendBody: true,
                  backgroundColor: primaryBackground,
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ───── Header ─────
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5, right: 23),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [const Header(), const Spacer()],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ───── Back / Cancel ─────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  size: 16,
                                ),
                              ),
                              const Text(
                                'Сообщения с компаниями',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 21),

                        // ───── Tabs ─────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        CompanyMessagesListScreen.routeName,
                                      );
                                    },
                                    child: Text(
                                      'Основные',
                                      style: TextStyle(
                                        color: isMainSelected
                                            ? CompanyMessagesArchiveListScreen
                                                  .accentColor
                                            : Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Не прочитанные: 234',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isMainSelected = false;
                                      });
                                    },
                                    child: Text(
                                      'Архив',
                                      style: TextStyle(
                                        color: isMainSelected
                                            ? Colors.white
                                            : CompanyMessagesArchiveListScreen
                                                  .accentColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 1,
                                    width: double.infinity,
                                    color: Colors.white24,
                                  ),
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 200),
                                    left: isMainSelected
                                        ? 0
                                        : 318, // Примерная позиция для второй вкладки
                                    child: Container(
                                      height: 2,
                                      width: isMainSelected
                                          ? 75
                                          : 45, // Ширина подчеркивания
                                      color: CompanyMessagesArchiveListScreen
                                          .accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ───── Select all / Archive ─────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Row(
                            children: [
                              CustomCheckbox(
                                value: selectAll,
                                onChanged: (value) {
                                  setState(() {
                                    selectAll = value;
                                    for (
                                      int i = 0;
                                      i < selectedItems.length;
                                      i++
                                    ) {
                                      selectedItems[i] = selectAll;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectAll = !selectAll;
                                    for (
                                      int i = 0;
                                      i < selectedItems.length;
                                      i++
                                    ) {
                                      selectedItems[i] = selectAll;
                                    }
                                  });
                                },
                                child: const Text(
                                  'Выбрать все',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  final selectedIndices = selectedItems
                                      .asMap()
                                      .entries
                                      .where((entry) => entry.value)
                                      .map((entry) => entry.key)
                                      .toList();
                                  context.read<CompanyMessagesBloc>().add(
                                    UnarchiveCompanyMessages(selectedIndices),
                                  );
                                  setState(() {
                                    selectedItems = List.filled(
                                      archivedMessages.length -
                                          selectedIndices.length,
                                      false,
                                    );
                                    selectAll = false;
                                  });
                                },
                                child: const Text(
                                  'Убрать из архива',
                                  style: TextStyle(
                                    color: UserMessagesArchiveListScreen
                                        .accentColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ───── List ─────
                        archivedMessages.isEmpty
                            ? Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/messages/non.png',
                                      width: 120,
                                      height: 120,
                                    ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
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
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 25,
                                  ),
                                  itemCount: archivedMessages.length,
                                  itemBuilder: (context, index) {
                                    return _MessageItem(
                                      name: archivedMessages[index]['name'],
                                      subtitle:
                                          archivedMessages[index]['subtitle'],
                                      unreadCount:
                                          archivedMessages[index]['unreadCount'],
                                      selected: selectedItems[index],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedItems[index] = value ?? false;
                                          selectAll = selectedItems.every(
                                            (item) => item,
                                          );
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: BottomNavigation(
                    onItemSelected: (index) {
                      if (index == 3) {
                        // Shopping cart icon
                        context.read<NavigationBloc>().add(
                          NavigateToMyPurchasesEvent(),
                        );
                      } else {
                        context.read<NavigationBloc>().add(
                          SelectNavigationIndexEvent(index),
                        );
                      }
                    },
                  ),
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MESSAGE ITEM
// ─────────────────────────────────────────────

class _MessageItem extends StatelessWidget {
  final String name;
  final String subtitle;
  final String unreadCount;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  const _MessageItem({
    required this.name,
    required this.subtitle,
    required this.unreadCount,
    this.selected = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            CustomCheckbox(value: selected, onChanged: onChanged),
            const SizedBox(width: 12),

            // avatar placeholder
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CompanyMessagesArchiveListScreen.cardColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white24),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),

            // unread badge
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? CompanyMessagesArchiveListScreen.accentColor
                      : CompanyMessagesArchiveListScreen.unreadBorder,
                ),
              ),
              child: Center(
                child: Text(
                  unreadCount,
                  style: TextStyle(
                    color: selected
                        ? CompanyMessagesArchiveListScreen.accentColor
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
