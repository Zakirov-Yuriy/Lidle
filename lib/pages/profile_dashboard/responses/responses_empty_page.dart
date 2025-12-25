import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/responses_sort_dialog.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/pages/profile_dashboard/responses/widgets/response_card.dart';

class ResponsesEmptyPage extends StatefulWidget {
  static const routeName = '/responses-empty';

  const ResponsesEmptyPage({super.key});

  @override
  State<ResponsesEmptyPage> createState() => _ResponsesEmptyPageState();
}

class _ResponsesEmptyPageState extends State<ResponsesEmptyPage> {
  String _currentSort = 'По сумме оплаты';
  int _currentTab = 0;

  // Separate lists for different tabs
  List<ResponseModel> mainResponses = [
    ResponseModel(
      id: '1',
      category: 'Услуги пешего курьера',
      title: 'Забрать лекарства',
      price: 600,
      userName: 'Адрей Петров',
      userAvatar: 'assets/responses/image1.png',
      rating: 5,
      phoneNumbers: ['+7 949 456 78 76', '+7 949 456 78 76'],
      telegram: '@AndrawP',
      whatsapp: '@AndrawP',
      vk: '@AndrawP',
      city: 'Мариуполь',
    ),
    ResponseModel(
      id: '3',
      category: 'Услуги по доставке',
      title: 'Доставить документы',
      price: 450,
      userName: 'Мария Иванова',
      userAvatar: 'assets/responses/image2.png',
      rating: 4.5,
      phoneNumbers: ['+7 999 123 45 67'],
      telegram: '@maria_iv',
      whatsapp: '@maria_iv',
      vk: '@maria_iv',
      city: 'Москва',
    ),
  ];

  List<ResponseModel> performingResponses = [
    ResponseModel(
      id: '2',
      category: 'Услуги пешего курьера',
      title: 'Забрать лекарства',
      price: 600,
      userName: 'Дмитрий Вайт',
      userAvatar: 'assets/responses/image2.png',
      rating: 4,
      phoneNumbers: ['+7 949 111 22 33'],
      telegram: '@dmitry_v',
      city: 'Донецк',
    ),
    ResponseModel(
      id: '4',
      category: 'Услуги водителя',
      title: 'Перевезти груз',
      price: 1200,
      userName: 'Алексей Смирнов',
      userAvatar: 'assets/responses/image1.png',
      rating: 4.8,
      phoneNumbers: ['+7 987 654 32 10'],
      telegram: '@alex_driver',
      whatsapp: '@alex_driver',
      vk: '@alex_driver',
      city: 'Санкт-Петербург',
    ),
  ];

  List<ResponseModel> archivedResponses = [];
  Map<String, String> archiveReasons = {}; // Track archive reasons by response ID

  void _moveToArchive(ResponseModel response) {
    setState(() {
      performingResponses.remove(response);
      // Add to archived with 'completed' reason
      archivedResponses.add(response);
      archiveReasons[response.id] = 'completed';
    });
  }

  void _rejectResponse(ResponseModel response) {
    setState(() {
      if (mainResponses.contains(response)) {
        mainResponses.remove(response);
      } else if (performingResponses.contains(response)) {
        performingResponses.remove(response);
      }
      // Add to archived with 'rejected' reason
      archivedResponses.add(response);
      archiveReasons[response.id] = 'rejected';
    });
  }

  Widget _buildTabContent() {
    List<ResponseModel> currentResponses;
    String? status;

    switch (_currentTab) {
      case 0:
        currentResponses = mainResponses;
        status = null;
        break;
      case 1:
        currentResponses = performingResponses;
        status = 'Выполянется';
        break;
      case 2:
        currentResponses = archivedResponses;
        status = 'Архив';
        break;
      default:
        currentResponses = [];
        status = null;
    }

    if (currentResponses.isNotEmpty) {
      return ListView.builder(
        itemCount: currentResponses.length,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemBuilder: (context, index) {
          // Determine archive reason for archive tab
          String? archiveReason;
          if (_currentTab == 2) {
            // For archive tab, get the reason from the map
            archiveReason = archiveReasons[currentResponses[index].id] ?? 'completed';
          }

          return ResponseCard(
            response: currentResponses[index],
            status: status,
            archiveReason: archiveReason,
            onArchive: _currentTab == 1 ? () => _moveToArchive(currentResponses[index]) : null,
            onReject: (_currentTab == 0 || _currentTab == 1) ? () => _rejectResponse(currentResponses[index]) : null,
          );
        },
      );
    } else {
      // Different empty states for different tabs
      String imagePath;
      String title;
      String description;

      switch (_currentTab) {
        case 2: // Archive tab
          imagePath = 'assets/messages/non.png';
          title = 'Архив пуст';
          description = 'У вас нет сообщений в архиве, \nкак только вы перенесете ваши \nсообщения они будет тут \nотображенно';
          break;
        default: // Main and Performing tabs
          imagePath = 'assets/responses/responses.png';
          title = 'Ваши отклики пусты';
          description = 'У вас нет откликов на быструю\nподработку, как только вы уберете\nобъявление с активных оно тут\nпоявится';
      }

      return Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ResponsesSortDialog(
          currentSort: _currentSort,
          onSortChanged: (newSort) {
            setState(() {
              _currentSort = newSort;
            });
          },
        ),
      ),
    );
  }

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);
  

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
      child: Scaffold(
        extendBody: true,
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 25),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Header(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

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
                      'Отклики',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showSortDialog,
                      child: const Icon(Icons.swap_vert, color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ───── Tabs ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _currentTab = 0),
                          child: Text(
                            'Основные',
                            style: TextStyle(
                              color: _currentTab == 0 ? accentColor : Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () => setState(() => _currentTab = 1),
                          child: Text(
                            'Выполняемые',
                            style: TextStyle(
                              color: _currentTab == 1 ? accentColor : Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () => setState(() => _currentTab = 2),
                          child: Text(
                            'Архив',
                            style: TextStyle(
                              color: _currentTab == 2 ? accentColor : Colors.white,
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
                          left: _currentTab == 0 ? 0 : _currentTab == 1 ? 95 : 218,
                          child: Container(
                            height: 2,
                            width: _currentTab == 0 ? 75 : _currentTab == 1 ? 105 : 45,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ───── Content ─────
              Expanded(
                child: _buildTabContent(),
              ),

              // const SizedBox(height: 80), // под bottom nav
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          onItemSelected: (index) {
            if (index == 3) {
              // Shopping cart icon
              context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
            } else {
              context.read<NavigationBloc>().add(
                SelectNavigationIndexEvent(index),
              );
            }
          },
        ),
      ),
    );
  }
}
