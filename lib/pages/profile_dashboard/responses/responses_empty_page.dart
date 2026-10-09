import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/responses_sort_dialog.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/pages/profile_dashboard/responses/widgets/response_card.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/core/logger.dart';

class ResponsesEmptyPage extends StatefulWidget {
  static const routeName = '/responses-empty';

  const ResponsesEmptyPage({super.key});

  @override
  State<ResponsesEmptyPage> createState() => _ResponsesEmptyPageState();
}

class _ResponsesEmptyPageState extends State<ResponsesEmptyPage> {
  List<String> _currentSort = ['По сумме оплаты'];
  int _currentTopTab = 0; // 0 = Отклики мне, 1 = Мои отклики
  int _currentTab = 0;
  Map<String, bool> _selectedCards = {}; // Track selected cards
  bool _isSelectionMode = false; // Track selection mode for performing tab

  /// Идёт ли загрузка с сервера.
  bool _isLoading = true;

  /// Что пошло не так при загрузке. Пусто — всё в порядке.
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Забрать отклики с сервера (09.10.2026, задача 15).
  ///
  /// Две верхние вкладки это две разные ручки: «Отклики мне» спрашивает
  /// отклики на мои объявления, «Мои отклики» — те, что отправил я.
  ///
  /// Внутренние вкладки раскладываются по СОСТОЯНИЮ отклика:
  ///
  ///   Отклики      новые, автор их ещё не рассматривал
  ///   Выполняется  принятые
  ///   Архив        отклонённые
  ///
  /// Завершения сделки на сервере пока нет, это отдельный экран по макету,
  /// поэтому «Выполняется» означает «принят», а не «работа идёт».
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rows = _currentTopTab == 0
          ? await ApiService.getReceivedResponses()
          : await ApiService.getMyResponses();

      final items = rows.map(ResponseModel.fromJson).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        mainResponses = items.where((r) => r.isNew).toList();
        performingResponses = items.where((r) => r.isAccepted).toList();
        // В архиве два разных исхода: отказ и выполненная работа. Карточка
        // пишет о них по-разному, и смешивать их в одну кучу нельзя.
        archivedResponses =
            items.where((r) => r.isRejected || r.isCompleted).toList();

        archiveReasons = {
          for (final row in archivedResponses)
            row.id: row.isCompleted ? 'completed' : 'rejected',
        };

        _selectedCards = {};
        _isSelectionMode = false;
        _isLoading = false;
      });
    } catch (e) {
      log.d('Не удалось загрузить отклики: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _error = '$e'.contains('авторизация')
            ? 'Войдите, чтобы увидеть отклики'
            : 'Не удалось загрузить отклики';
      });
    }
  }

  /// Принять отклик: состояние 2.
  Future<void> _accept(ResponseModel response) => _setStatus(response, 2);

  /// Отклонить отклик: состояние 3.
  Future<void> _setRejected(ResponseModel response) => _setStatus(response, 3);

  /// Поменять состояние на сервере и перечитать список.
  ///
  /// Перечитываем, а не двигаем карточку в памяти: состояние меняет сервер, и
  /// расходиться с ним на экране незачем. Отклик могли уже рассмотреть с
  /// другого устройства.
  Future<void> _setStatus(ResponseModel response, int statusId) async {
    final id = response.responseId;

    if (id == null) {
      return;
    }

    try {
      final result = await ApiService.updateResponseStatus(
        responseId: id,
        statusId: statusId,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['message'] ?? 'Не получилось'}'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      await _load();
    } catch (e) {
      log.d('Не удалось поменять состояние отклика: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не получилось, попробуйте ещё раз'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Списки заполняются из ответа сервера, см. _load(). Придуманные данные
  // отсюда убраны: экран показывал «Адрей Петров» и «Мариуполь» всем подряд.
  List<ResponseModel> mainResponses = [
    // ResponseModel(
    //   id: '1',
    //   category: 'Услуги пешего курьера',
    //   title: 'Забрать лекарства',
    //   price: 600,
    //   userName: 'Адрей Петров',
    //   userAvatar: 'assets/responses/image1.png',
    //   rating: 5,
    //   phoneNumbers: ['+7 949 456 78 76', '+7 949 456 78 76'],
    //   telegram: '@AndrawP',
    //   whatsapp: '@AndrawP',
    //   vk: '@AndrawP',
    //   city: 'Мариуполь',
    // ),
    // ResponseModel(
    //   id: '3',
    //   category: 'Услуги по доставке',
    //   title: 'Доставить документы',
    //   price: 450,
    //   userName: 'Мария Иванова',
    //   userAvatar: 'assets/responses/image2.png',
    //   rating: 4.5,
    //   phoneNumbers: ['+7 999 123 45 67'],
    //   telegram: '@maria_iv',
    //   whatsapp: '@maria_iv',
    //   vk: '@maria_iv',
    //   city: 'Москва',
    // ),
  ];

  List<ResponseModel> performingResponses = [
    // ResponseModel(
    //   id: '2',
    //   category: 'Услуги пешего курьера',
    //   title: 'Забрать лекарства',
    //   price: 600,
    //   userName: 'Дмитрий Вайт',
    //   userAvatar: 'assets/responses/image2.png',
    //   rating: 4,
    //   phoneNumbers: ['+7 949 111 22 33'],
    //   telegram: '@dmitry_v',
    //   city: 'Донецк',
    // ),
    // ResponseModel(
    //   id: '4',
    //   category: 'Услуги водителя',
    //   title: 'Перевезти груз',
    //   price: 1200,
    //   userName: 'Алексей Смирнов',
    //   userAvatar: 'assets/responses/image1.png',
    //   rating: 4.8,
    //   phoneNumbers: ['+7 987 654 32 10'],
    //   telegram: '@alex_driver',
    //   whatsapp: '@alex_driver',
    //   vk: '@alex_driver',
    //   city: 'Санкт-Петербург',
    // ),
  ];

  List<ResponseModel> archivedResponses = [];
  Map<String, String> archiveReasons =
      {}; // Track archive reasons by response ID

  /// Завершить работу по отклику: состояние 4.
  ///
  /// Раньше карточка просто переезжала в архив в памяти, и после обновления
  /// экрана возвращалась обратно. Теперь это решение, и живёт оно на сервере.
  Future<void> _complete(ResponseModel response) => _setStatus(response, 4);

  /// Отклонить всё выбранное.
  ///
  /// По одному запросу на отклик: пакетной ручки на сервере нет, а делать её
  /// ради кнопки, которой пользуются редко, незачем. Список перечитывается
  /// один раз в конце, а не после каждого.
  Future<void> _rejectSelectedCards() async {
    final selectedIds = _selectedCards.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    for (final id in selectedIds) {
      final response = performingResponses.firstWhereOrNull((r) => r.id == id);
      final responseId = response?.responseId;

      if (responseId == null) {
        continue;
      }

      try {
        await ApiService.updateResponseStatus(
          responseId: responseId,
          statusId: 3,
        );
      } catch (e) {
        log.d('Не удалось отклонить отклик $responseId: $e');
      }
    }

    if (mounted) {
      await _load();
    }
  }

  void _enterSelectionMode(String responseId) {
    setState(() {
      _isSelectionMode = true;
      _selectedCards[responseId] = true;
    });
  }

  void _selectAllCards(bool selectAll) {
    setState(() {
      List<ResponseModel> currentResponses;
      switch (_currentTab) {
        case 1:
          currentResponses = performingResponses;
          break;
        case 2:
          currentResponses = archivedResponses;
          break;
        default:
          currentResponses = [];
      }

      for (final response in currentResponses) {
        _selectedCards[response.id] = selectAll;
      }

      // Exit selection mode if deselecting all
      if (!selectAll) {
        _isSelectionMode = false;
      }
    });
  }

  Widget _buildTabContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00B7FF)),
                ),
                child: const Text(
                  'Обновить',
                  style: TextStyle(color: Color(0xFF00B7FF)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    List<ResponseModel> currentResponses;
    String? status;

    switch (_currentTab) {
      case 0:
        currentResponses = mainResponses;
        status = null;
        break;
      case 1:
        currentResponses = performingResponses;
        status = 'Выполняется';
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
      final bool allSelected =
          currentResponses.isNotEmpty &&
          currentResponses.every((r) => _selectedCards[r.id] ?? false);
      final bool anySelected = currentResponses.any(
        (r) => _selectedCards[r.id] ?? false,
      );

      return Column(
        children: [
          // Show selection header for performing tab
          if (_currentTab == 1 && _isSelectionMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              child: Row(
                children: [
                  CustomCheckbox(
                    value: allSelected,
                    onChanged: (value) {
                      _selectAllCards(value);
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Выбрать все',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (anySelected)
                    GestureDetector(
                      onTap: _rejectSelectedCards,
                      child: const Text(
                        'Отклонить',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // В архиве выбора НЕТ (09.10.2026).
          //
          // Там были «Из архива» и «Удалить» с макета, и обе работали только
          // в памяти: сервер возвращать отклонённый отклик в работу не умеет
          // и не должен. После обновления экрана всё возвращалось назад, и
          // выглядело это как потерянное действие.
          //
          // Архив это не папка, а след решения: отклонили, и так оно и
          // осталось. Нужен человек снова — он откликнется ещё раз.
          Expanded(
            child: ListView.builder(
              itemCount: currentResponses.length,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemBuilder: (context, index) {
                // Determine archive reason for archive tab
                String? archiveReason;
                if (_currentTab == 2) {
                  // For archive tab, get the reason from the map
                  archiveReason =
                      archiveReasons[currentResponses[index].id] ?? 'completed';
                }

                // Initialize selection state for new cards
                _selectedCards.putIfAbsent(
                  currentResponses[index].id,
                  () => false,
                );

                return ResponseCard(
                  response: currentResponses[index],
                  status: status,
                  archiveReason: archiveReason,
                  showCheckbox: _currentTab == 1 && _isSelectionMode,
                  isSelected:
                      _selectedCards[currentResponses[index].id] ?? false,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedCards[currentResponses[index].id] = selected;

                      // Exit selection mode if no items are checked
                      if (!_selectedCards.values.any((v) => v)) {
                        _isSelectionMode = false;
                      }
                    });
                  },
                  onLongPress: _currentTab == 1
                      ? () {
                          if (!_isSelectionMode) {
                            _enterSelectionMode(currentResponses[index].id);
                          }
                        }
                      : null,
                  // «Завершить» на вкладке «Выполняется»: только у автора
                  // объявления, он же принимал отклик.
                  onComplete: _currentTopTab == 0 && _currentTab == 1
                      ? () => _complete(currentResponses[index])
                      : null,
                  // Отклонить может только автор объявления: на своих
                  // откликах сервер ответит отказом, и кнопку показывать
                  // незачем.
                  onReject: _currentTopTab == 0 &&
                          (_currentTab == 0 || _currentTab == 1)
                      ? () => _setRejected(currentResponses[index])
                      : null,
                  // Принять отклик: только у откликов НА МОИ объявления.
                  // Свой собственный отклик принимать нельзя, это решение
                  // автора объявления.
                  onAccept: _currentTopTab == 0 && _currentTab == 0
                      ? () => _accept(currentResponses[index])
                      : null,
                );
              },
            ),
          ),
        ],
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
          description =
              'У вас нет сообщений в архиве, \nкак только вы перенесете ваши \nсообщения они будет тут \nотображенно';
          break;
        default: // Main and Performing tabs
          imagePath = 'assets/responses/responses.png';
          title = 'Ваши отклики пусты';
          description =
              'У вас нет откликов на быструю\nподработку, как только вы уберете\nобъявление с активных оно тут\nпоявится';
      }

      return Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 120, fit: BoxFit.contain),
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
          bottom: false,
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
                      // Нажатие на всю строку, а не только на стрелку: попасть пальцем
                      // в иконку шириной 16 точек трудно, а заголовок рядом читается
                      // как часть той же кнопки «назад».
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_ios,
                            color: Color.fromARGB(255, 255, 255, 255),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Отклики',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

              // ───── Top Tabs (Отклики мне / Мои отклики) ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_currentTopTab == 0) {
                              return;
                            }

                            setState(() => _currentTopTab = 0);
                            _load();
                          },
                          child: Text(
                            'Отклики мне',
                            style: TextStyle(
                              color: _currentTopTab == 0
                                  ? accentColor
                                  : Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () {
                            if (_currentTopTab == 1) {
                              return;
                            }

                            setState(() => _currentTopTab = 1);
                            _load();
                          },
                          child: Text(
                            'Мои отклики',
                            style: TextStyle(
                              color: _currentTopTab == 1
                                  ? accentColor
                                  : Colors.white,
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
                          left: _currentTopTab == 0 ? 0 : 115,
                          child: Container(
                            height: 2,
                            width: _currentTopTab == 0 ? 105 : 95,
                            color: accentColor,
                          ),
                        ),
                      ],
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
                              color: _currentTab == 0
                                  ? accentColor
                                  : Colors.white,
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
                              color: _currentTab == 1
                                  ? accentColor
                                  : Colors.white,
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
                              color: _currentTab == 2
                                  ? accentColor
                                  : Colors.white,
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
                          left: _currentTab == 0
                              ? 0
                              : _currentTab == 1
                              ? 95
                              : 218,
                          child: Container(
                            height: 2,
                            width: _currentTab == 0
                                ? 75
                                : _currentTab == 1
                                ? 105
                                : 45,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ───── Content ─────
              Expanded(child: _buildTabContent()),
              SizedBox(height: bottomNavHeight + bottomNavPaddingBottom + 16),
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
