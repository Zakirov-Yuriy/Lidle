import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/responses_sort_dialog.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/indoor_advertising_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/outdoor_advertising_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_property_details_screen.dart';

class MyListingsScreen extends StatefulWidget {
  static const routeName = '/my-listings';

  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  int _currentTab = 0;
  int _selectedCatalog = 0; // 0: Недвижимость, 1: Авто
  int _selectedCategory = 0; // 0: Квартиры, 1: Гаражи
  bool _selectAllChecked = false;
  Set<int> _selectedListingIds = {};

  static const accentColor = Color(0xFF00B7FF);
  static const yellowColor = Color(0xFFE8FF00);
  static const greenColor = Color(0xFF00D084);

  List<String> _currentSort = ['По цене'];

  List<Map<String, dynamic>> _activeListings = [
    {'id': 1},
    {'id': 2},
  ];
  List<Map<String, dynamic>> _inactiveListings = [];
  List<Map<String, dynamic>> _archiveListings = [];
  List<Map<String, dynamic>> _moderationListings = [
    {'id': 3},
  ];

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

  void _showDeleteMultipleDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2732),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 24),
                  const Text(
                    'Удалить публикации',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Внимание: ',
                          style: TextStyle(color: Color(0xFFE8FF00)),
                        ),
                        TextSpan(
                          text: 'если вы хотите\nудалить выбранные публикации.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Подтвердите действие',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00B7FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _deleteSelected();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Подтвердить',
                        style: TextStyle(color: Color(0xFF00B7FF)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToMessages) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return Scaffold(
            extendBody: true,
            backgroundColor: primaryBackground,
            body: SafeArea(
              child: ListView(
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
                          'Активные / Неактивные',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _showSortDialog,
                          child: const Icon(
                            Icons.swap_vert,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ───── Catalog ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Каталог',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _catalogButton(
                              'Недвижимость',
                              _selectedCatalog == 0,
                              onPressed: () =>
                                  setState(() => _selectedCatalog = 0),
                            ),
                            const SizedBox(width: 8),
                            _catalogButton(
                              'Авто',
                              _selectedCatalog == 1,
                              onPressed: () =>
                                  setState(() => _selectedCatalog = 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ───── Categories ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Категории',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _catalogButton(
                              'Квартиры',
                              _selectedCategory == 0,
                              onPressed: () =>
                                  setState(() => _selectedCategory = 0),
                            ),
                            const SizedBox(width: 8),
                            _catalogButton(
                              'Гаражи',
                              _selectedCategory == 1,
                              onPressed: () =>
                                  setState(() => _selectedCategory = 1),
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
                                'Активные',
                                style: TextStyle(
                                  color: _currentTab == 0
                                      ? accentColor
                                      : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => setState(() => _currentTab = 1),
                              child: Text(
                                'Неактивные',
                                style: TextStyle(
                                  color: _currentTab == 1
                                      ? accentColor
                                      : Colors.white,
                                  fontSize: 14,
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
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () => setState(() => _currentTab = 3),
                              child: Text(
                                'На модерации',
                                style: TextStyle(
                                  color: _currentTab == 3
                                      ? accentColor
                                      : Colors.white,
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
                              left: _currentTab == 0
                                  ? 0
                                  : _currentTab == 1
                                  ? 88
                                  : _currentTab == 2
                                  ? 192
                                  : 254,
                              child: Container(
                                height: 2,
                                width: _currentTab == 0
                                    ? 68
                                    : _currentTab == 1
                                    ? 84
                                    : _currentTab == 2
                                    ? 42
                                    : 98,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ───── Select all section ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      children: [
                        CustomCheckbox(
                          value: _selectAllChecked,
                          onChanged: (value) {
                            setState(() {
                              _selectAllChecked = value;
                              if (_selectAllChecked) {
                                // Select all listings from current tab
                                final currentListings =
                                    _getCurrentTabListings();
                                _selectedListingIds.addAll(
                                  currentListings.map((l) => l['id'] as int),
                                );
                              } else {
                                _selectedListingIds.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Выбрать все',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedListingIds.isNotEmpty) ...[
                          if (_currentTab != 3) ...[
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _moveToArchive();
                                });
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
                            const SizedBox(width: 10),
                            Container(
                              width: 1,
                              height: 19,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 10),
                          ],
                          GestureDetector(
                            onTap: () {
                              _showDeleteMultipleDialog();
                            },
                            child: const Text(
                              'Удалить',
                              style: TextStyle(
                                color: Color(0xFFFF3B30),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ───── Content ─────
                  _buildTabContent(),
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
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIVE TAB
  // ─────────────────────────────────────────────

  Widget _activeTab() {
    if (_activeListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'Активные пусты',
        'У вас нет активных объявлений,\nкак только вы добавите\nобъявление оно тут появится',
      );
    }
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < _activeListings.length; i++) ...[
          _listingCard(_activeListings[i]['id'], 0),
          if (i < _activeListings.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // INACTIVE TAB
  // ─────────────────────────────────────────────

  Widget _inactiveTab() {
    if (_inactiveListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'Неактивные пусты',
        'У вас нет неактивных объявлений,\nкак только вы деактивируете\nобъявление оно тут появится',
      );
    }
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < _inactiveListings.length; i++) ...[
          _listingCard(_inactiveListings[i]['id'], 1),
          if (i < _inactiveListings.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ARCHIVE TAB
  // ─────────────────────────────────────────────

  Widget _archiveTab() {
    if (_archiveListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'Архив пуст',
        'У вас нет объявлений в архиве,\nкак только вы перенесете\nобъявления они будут тут',
      );
    }
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < _archiveListings.length; i++) ...[
          _listingCard(_archiveListings[i]['id'], 2),
          if (i < _archiveListings.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // MODERATION TAB
  // ─────────────────────────────────────────────

  Widget _moderationTab() {
    if (_moderationListings.isEmpty) {
      return _emptyTab(
        'assets/messages/non.png',
        'На модерации пусто',
        'У вас нет объявлений на модерации,\nкак только вы отправите\nобъявление оно тут появится',
      );
    }
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < _moderationListings.length; i++) ...[
          _listingCard(_moderationListings[i]['id'], 3),
          if (i < _moderationListings.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // LISTING CARD
  // ─────────────────────────────────────────────

  Widget _listingCard(int id, int tabIndex) {
    final isSelected = _selectedListingIds.contains(id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image + info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCheckbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selectedListingIds.add(id);
                    } else {
                      _selectedListingIds.remove(id);
                    }
                    _selectAllChecked = false;
                  });
                },
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MyListingsPropertyDetailsScreen(),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/home_page/image2.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3-к. квартира, 125,5 м², 5/17 эт.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '44 500 000 ₽',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '354 582 ₽ за м²',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(color: Colors.white24, height: 24),

          if (tabIndex == 3) ...[
            const Center(
              child: Text(
                'Объявление находится на модерации. В течении 24 часов администрация проверит ваше объявление',
                textAlign: TextAlign.start,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(child: _actionButton('Поддержка Лидле', Colors.white)),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    'Редактировать',
                    accentColor,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DynamicFilter(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ] else ...[
            const Text(
              'Просмотров: 340',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Переходов: 24',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Поделились: 14',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),

            const SizedBox(height: 16),

            if (tabIndex == 0) ...[
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      'Деактивировать',
                      yellowColor,
                      onPressed: () {
                        setState(() {
                          final listing = _activeListings.firstWhere(
                            (l) => l['id'] == id,
                          );
                          _activeListings.remove(listing);
                          _inactiveListings.add(listing);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      'Редактировать',
                      accentColor,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DynamicFilter(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // const SizedBox(height: 12),
            ],

            if (tabIndex == 1)
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      'Активировать',
                      greenColor,
                      onPressed: () {
                        setState(() {
                          final listing = _inactiveListings.firstWhere(
                            (l) => l['id'] == id,
                          );
                          _inactiveListings.remove(listing);
                          _activeListings.add(listing);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      'Редактировать',
                      accentColor,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DynamicFilter(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            if (tabIndex == 2)
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      'Активировать',
                      greenColor,
                      onPressed: () {
                        setState(() {
                          final listing = _archiveListings.firstWhere(
                            (l) => l['id'] == id,
                          );
                          _archiveListings.remove(listing);
                          _activeListings.add(listing);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      'Редактировать',
                      accentColor,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DynamicFilter(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    'Наружная реклама',
                    Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const OutdoorAdvertisingScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    'Внутренняя реклама',
                    Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IndoorAdvertisingScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUTTON
  // ─────────────────────────────────────────────

  Widget _actionButton(String title, Color color, {VoidCallback? onPressed}) {
    return SizedBox(
      height: 39,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed ?? () {},
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CATALOG BUTTON
  // ─────────────────────────────────────────────

  Widget _catalogButton(
    String title,
    bool isActive, {
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isActive ? accentColor : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? accentColor : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD TAB CONTENT
  // ─────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _activeTab();
      case 1:
        return _inactiveTab();
      case 2:
        return _archiveTab();
      case 3:
        return _moderationTab();
      default:
        return _activeTab();
    }
  }

  // ─────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────

  List<Map<String, dynamic>> _getCurrentTabListings() {
    switch (_currentTab) {
      case 0:
        return _activeListings;
      case 1:
        return _inactiveListings;
      case 2:
        return _archiveListings;
      case 3:
        return _moderationListings;
      default:
        return _activeListings;
    }
  }

  void _moveToArchive() {
    if (_selectedListingIds.isEmpty) return;

    setState(() {
      if (_currentTab == 0) {
        final toArchive = _activeListings
            .where((l) => _selectedListingIds.contains(l['id']))
            .toList();
        _activeListings.removeWhere(
          (l) => _selectedListingIds.contains(l['id']),
        );
        _archiveListings.addAll(toArchive);
      } else if (_currentTab == 1) {
        final toArchive = _inactiveListings
            .where((l) => _selectedListingIds.contains(l['id']))
            .toList();
        _inactiveListings.removeWhere(
          (l) => _selectedListingIds.contains(l['id']),
        );
        _archiveListings.addAll(toArchive);
      } else if (_currentTab == 2) {
        // Already in archive, no action needed
      } else if (_currentTab == 3) {
        final toArchive = _moderationListings
            .where((l) => _selectedListingIds.contains(l['id']))
            .toList();
        _moderationListings.removeWhere(
          (l) => _selectedListingIds.contains(l['id']),
        );
        _archiveListings.addAll(toArchive);
      }
      _selectedListingIds.clear();
      _selectAllChecked = false;
    });
  }

  void _deleteSelected() {
    if (_selectedListingIds.isEmpty) return;

    setState(() {
      if (_currentTab == 0) {
        _activeListings.removeWhere(
          (l) => _selectedListingIds.contains(l['id']),
        );
      } else if (_currentTab == 1) {
        _inactiveListings.removeWhere(
          (l) => _selectedListingIds.contains(l['id']),
        );
      } else if (_currentTab == 2) {
        _archiveListings.removeWhere(
          (l) => _selectedListingIds.contains(l['id']),
        );
      } else if (_currentTab == 3) {
        _moderationListings.removeWhere(
          (l) => _selectedListingIds.contains(l['id']),
        );
      }
      _selectedListingIds.clear();
      _selectAllChecked = false;
    });
  }

  // ─────────────────────────────────────────────
  // EMPTY TAB
  // ─────────────────────────────────────────────

  Widget _emptyTab(String imagePath, String title, String description) {
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
