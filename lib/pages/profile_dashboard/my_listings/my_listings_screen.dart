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
import 'package:lidle/services/catalog_service.dart';
import 'package:lidle/models/catalog_category_model.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/hive_service.dart';

class MyListingsScreen extends StatefulWidget {
  static const routeName = '/my-listings';

  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  int _currentTab = 0;
  int _selectedCatalogIndex = 0; // Индекс выбранного каталога
  int _selectedCategoryIndex = 0; // Индекс выбранной категории
  bool _selectAllChecked = false;
  bool _isSelectionMode = false; // Режим выбора
  Set<int> _selectedListingIds = {};

  static const accentColor = Color(0xFF00B7FF);
  static const yellowColor = Color(0xFFE8FF00);
  static const greenColor = Color(0xFF00D084);

  List<String> _currentSort = ['По цене'];

  // Мета-данные объявлений (только каталоги и категории с объявлениями)
  List<AdvertMetaCatalog> _advertMetaCatalogs = [];
  List<AdvertMetaCategory> _advertMetaCategories = [];
  bool _isLoadingMetadata = true;
  String? _errorMessage;

  // Реальные объявления с API
  List<UserAdvert> _activeListings = [];
  List<UserAdvert> _inactiveListings = [];
  List<UserAdvert> _archiveListings = [];
  List<UserAdvert> _moderationListings = [];
  bool _isLoadingListings = true;

  @override
  void initState() {
    super.initState();
    _loadAdvertMetadata();
    _loadAllListings();
  }

  /// Загрузить мета-информацию объявлений (каталоги и категории с объявлениями)
  Future<void> _loadAdvertMetadata() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoadingMetadata = false;
            _errorMessage = 'Токен не найден';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _isLoadingMetadata = true);
      }

      final response = await MyAdvertsService.getAdvertsMeta(token: token);

      if (response.data.isNotEmpty) {
        final metaData = response.data[0];
        if (mounted) {
          setState(() {
            _advertMetaCatalogs = metaData.catalogs;
            if (_advertMetaCatalogs.isNotEmpty) {
              _advertMetaCategories = _advertMetaCatalogs[0].categories;
            }
            _isLoadingMetadata = false;
          });
        }
      }
    } catch (e) {
      print('=== Ошибка загрузки мета-информации объявлений: $e');
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
          _errorMessage = 'Ошибка загрузки мета-информации: $e';
        });
      }
    }
  }

  /// Загрузить все объявления разных статусов
  Future<void> _loadAllListings() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoadingListings = false;
            _errorMessage = 'Токен не найден';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _isLoadingListings = true);
      }

      // Загружаем объявления всех статусов параллельно
      final results = await Future.wait([
        MyAdvertsService.getMyAdverts(statusId: 1, token: token),
        MyAdvertsService.getMyAdverts(statusId: 2, token: token),
        MyAdvertsService.getMyAdverts(statusId: 3, token: token),
        MyAdvertsService.getMyAdverts(statusId: 8, token: token),
      ]);

      if (mounted) {
        setState(() {
          _activeListings = results[0].data;
          _inactiveListings = results[1].data;
          _moderationListings = results[2].data;
          _archiveListings = results[3].data;
          _isLoadingListings = false;
        });
      }
    } catch (e) {
      print('=== Ошибка загрузки объявлений: $e');
      if (mounted) {
        setState(() {
          _isLoadingListings = false;
          _errorMessage = 'Ошибка загрузки объявлений: $e';
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage ?? 'Ошибка загрузки')),
        );
      }
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
              bottom: false,
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
                        if (_isLoadingMetadata)
                          const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00B7FF),
                              ),
                            ),
                          )
                        else if (_advertMetaCatalogs.isEmpty)
                          const Center(
                            child: Text(
                              'Каталоги не найдены',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(
                                _advertMetaCatalogs.length,
                                (index) => Padding(
                                  padding: EdgeInsets.only(
                                    right:
                                        index < _advertMetaCatalogs.length - 1
                                        ? 8
                                        : 0,
                                  ),
                                  child: _catalogButton(
                                    _advertMetaCatalogs[index].name,
                                    _selectedCatalogIndex == index,
                                    onPressed: () {
                                      setState(() {
                                        _selectedCatalogIndex = index;
                                        _advertMetaCategories =
                                            _advertMetaCatalogs[index]
                                                .categories;
                                        _selectedCategoryIndex = 0;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
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
                        if (_isLoadingMetadata)
                          const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00B7FF),
                              ),
                            ),
                          )
                        else if (_advertMetaCategories.isEmpty)
                          const Center(
                            child: Text(
                              'Категории не найдены',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(
                                _advertMetaCategories.length,
                                (index) => Padding(
                                  padding: EdgeInsets.only(
                                    right:
                                        index < _advertMetaCategories.length - 1
                                        ? 8
                                        : 0,
                                  ),
                                  child: _catalogButton(
                                    _advertMetaCategories[index].name,
                                    _selectedCategoryIndex == index,
                                    onPressed: () {
                                      setState(
                                        () => _selectedCategoryIndex = index,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _currentTab = 0),
                                child: Text(
                                  _activeListings.isEmpty
                                      ? 'Активные'
                                      : 'Активные ${_activeListings.length}',
                                  style: TextStyle(
                                    color: _currentTab == 0
                                        ? accentColor
                                        : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => setState(() => _currentTab = 1),
                                child: Text(
                                  _inactiveListings.isEmpty
                                      ? 'Неактивные'
                                      : 'Неактивные ${_inactiveListings.length}',
                                  style: TextStyle(
                                    color: _currentTab == 1
                                        ? accentColor
                                        : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => setState(() => _currentTab = 2),
                                child: Text(
                                  _archiveListings.isEmpty
                                      ? 'Архив'
                                      : 'Архив ${_archiveListings.length}',
                                  style: TextStyle(
                                    color: _currentTab == 2
                                        ? accentColor
                                        : Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => setState(() => _currentTab = 3),
                                child: Text(
                                  _moderationListings.isEmpty
                                      ? 'На модерации'
                                      : 'На модерации ${_moderationListings.length}',
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
                              left: _getTabPosition(_currentTab),
                              child: Container(
                                height: 2,
                                width: _getTabWidth(_currentTab),
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
                  if (_isSelectionMode)
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
                                    currentListings.map((l) => l.id),
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
                              fontSize: 15,
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
                                child: Text(
                                  _currentTab == 2 ? 'Из архива' : 'В архив',
                                  style: const TextStyle(
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
                  SizedBox(
                    height: bottomNavHeight + bottomNavPaddingBottom + 16,
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
          _listingCard(_activeListings[i], 0),
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
          _listingCard(_inactiveListings[i], 1),
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
          _listingCard(_archiveListings[i], 2),
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
          _listingCard(_moderationListings[i], 3),
          if (i < _moderationListings.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // LISTING CARD
  // ─────────────────────────────────────────────

  Widget _listingCard(UserAdvert advert, int tabIndex) {
    final isSelected = _selectedListingIds.contains(advert.id);

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedListingIds.add(advert.id);
        });
      },
      child: Container(
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
                if (_isSelectionMode)
                  CustomCheckbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _selectedListingIds.add(advert.id);
                        } else {
                          _selectedListingIds.remove(advert.id);
                          // Выйти из режима выбора если ничего не выбрано
                          if (_selectedListingIds.isEmpty) {
                            _isSelectionMode = false;
                            _selectAllChecked = false;
                          }
                        }
                        _selectAllChecked = false;
                      });
                    },
                  ),
                if (_isSelectionMode) const SizedBox(width: 12),
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
                    child: advert.thumbnail != null
                        ? Image.network(
                            advert.thumbnail!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 72,
                                height: 72,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.image,
                              color: Colors.white54,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advert.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${advert.price} ₽',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        advert.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
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
                  Expanded(
                    child: _actionButton('Поддержка Лидле', Colors.white),
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
                            builder: (context) =>
                                DynamicFilter(categoryId: advert.type.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ] else ...[
              Text(
                'Просмотров: ${advert.viewsCount}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Переходов: ${advert.clickCount}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Поделились: ${advert.shareCount}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
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
                          _deactivateAdvert(advert.id);
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
                              builder: (context) =>
                                  DynamicFilter(categoryId: advert.type.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],

              if (tabIndex == 1)
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Активировать',
                        greenColor,
                        onPressed: () {
                          _activateAdvert(advert.id);
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
                              builder: (context) =>
                                  DynamicFilter(categoryId: advert.type.id),
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
                          _activateAdvert(advert.id);
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
                              builder: (context) =>
                                  DynamicFilter(categoryId: advert.type.id),
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
                            builder: (context) =>
                                const IndoorAdvertisingScreen(),
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

  double _getTextWidth(String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 14, fontFamily: 'SF Pro Display'),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  double _getTabPosition(int tabIndex) {
    double position = 0;
    for (int i = 0; i < tabIndex; i++) {
      position += _getTabWidth(i) + 16; // 16 - это SizedBox между вкладками
    }
    // Корректировка для каждой вкладки отдельно
    if (tabIndex == 1) {
      position += 4; // Неактивные
    } else if (tabIndex == 2) {
      position += 4; // Архив
    } else if (tabIndex == 5) {
      position += 8; // На модерации
    }
    return position;
  }

  double _getTabWidth(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _getTextWidth(
          _activeListings.isEmpty
              ? 'Активные'
              : 'Активные ${_activeListings.length}',
        );
      case 1:
        return _getTextWidth(
          _inactiveListings.isEmpty
              ? 'Неактивные'
              : 'Неактивные ${_inactiveListings.length}',
        );
      case 2:
        return _getTextWidth(
          _archiveListings.isEmpty
              ? 'Архив'
              : 'Архив ${_archiveListings.length}',
        );
      case 3:
        return _getTextWidth(
          _moderationListings.isEmpty
              ? 'На модерации'
              : 'На модерации ${_moderationListings.length}',
        );
      default:
        return 0;
    }
  }

  List<UserAdvert> _getCurrentTabListings() {
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
            .where((l) => _selectedListingIds.contains(l.id))
            .toList();
        _activeListings.removeWhere((l) => _selectedListingIds.contains(l.id));
        _archiveListings.addAll(toArchive);
      } else if (_currentTab == 1) {
        final toArchive = _inactiveListings
            .where((l) => _selectedListingIds.contains(l.id))
            .toList();
        _inactiveListings.removeWhere(
          (l) => _selectedListingIds.contains(l.id),
        );
        _archiveListings.addAll(toArchive);
      } else if (_currentTab == 2) {
        // Из архива в активные
        final toActive = _archiveListings
            .where((l) => _selectedListingIds.contains(l.id))
            .toList();
        _archiveListings.removeWhere((l) => _selectedListingIds.contains(l.id));
        _activeListings.addAll(toActive);
      } else if (_currentTab == 3) {
        final toArchive = _moderationListings
            .where((l) => _selectedListingIds.contains(l.id))
            .toList();
        _moderationListings.removeWhere(
          (l) => _selectedListingIds.contains(l.id),
        );
        _archiveListings.addAll(toArchive);
      }
      _selectedListingIds.clear();
      _selectAllChecked = false;
      _isSelectionMode = false;
    });
  }

  void _deleteSelected() {
    if (_selectedListingIds.isEmpty) return;

    setState(() {
      if (_currentTab == 0) {
        _activeListings.removeWhere((l) => _selectedListingIds.contains(l.id));
      } else if (_currentTab == 1) {
        _inactiveListings.removeWhere(
          (l) => _selectedListingIds.contains(l.id),
        );
      } else if (_currentTab == 2) {
        _archiveListings.removeWhere((l) => _selectedListingIds.contains(l.id));
      } else if (_currentTab == 3) {
        _moderationListings.removeWhere(
          (l) => _selectedListingIds.contains(l.id),
        );
      }
      _selectedListingIds.clear();
      _selectAllChecked = false;
      _isSelectionMode = false;
    });
  }

  /// Активировать объявление
  void _activateAdvert(int advertId) async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      await MyAdvertsService.activateAdvert(advertId: advertId, token: token);

      // Перезагружаем все объявления для синхронизации с сервером
      await _loadAllListings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление активировано')),
        );
      }
    } catch (e) {
      print('Ошибка активации: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  /// Деактивировать объявление
  void _deactivateAdvert(int advertId) async {
    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) return;

      await MyAdvertsService.deactivateAdvert(advertId: advertId, token: token);

      // Перезагружаем все объявления для синхронизации с сервером
      await _loadAllListings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление деактивировано')),
        );
      }
    } catch (e) {
      print('Ошибка деактивации: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
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
