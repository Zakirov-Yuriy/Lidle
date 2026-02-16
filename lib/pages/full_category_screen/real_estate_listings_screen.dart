import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/cards/listing_card.dart';
import 'package:lidle/pages/full_category_screen/intermediate_filters_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/hive_service.dart';

// ============================================================
// "Универсальный экран объявлений по категориям"
// ============================================================

const String gridIconAsset = 'assets/BottomNavigation/grid-01.png';
const String messageIconAssetLocal =
    'assets/BottomNavigation/message-circle-01.png';
const String shoppingCartAsset = 'assets/BottomNavigation/shopping-cart-01.png';

class RealEstateListingsScreen extends StatefulWidget {
  final int? categoryId; // ID категории для фильтрации
  final int? catalogId; // ID каталога для фильтрации
  final String? categoryName; // Имя категории для отображения в заголовке

  const RealEstateListingsScreen({
    super.key,
    this.categoryId,
    this.catalogId,
    this.categoryName,
  });

  @override
  State<RealEstateListingsScreen> createState() =>
      _RealEstateListingsScreenState();
}

class _RealEstateListingsScreenState extends State<RealEstateListingsScreen> {
  int _selectedIndex = 0;
  List<Listing> _listings = [];
  Set<String> _selectedSortOptions = {};
  bool _isLoading = true;
  String? _errorMessage;

  // Пагинация
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _selectedSortOptions.add('Сначала новые');
    _loadAdverts();
  }

  Future<void> _loadAdverts({String? sort, bool isNextPage = false}) async {
    try {
      setState(() {
        if (!isNextPage) {
          _isLoading = true;
          _currentPage = 1; // Сбрасываем на первую страницу при новой загрузке
        }
        _errorMessage = null;
      });

      final token = await HiveService.getUserData('token');
      final response = await ApiService.getAdverts(
        categoryId: widget.categoryId,
        catalogId: widget.catalogId,
        sort: sort,
        page: isNextPage ? _currentPage + 1 : 1,
        limit: 20,
        token: token,
      );

      print('📊 API Response: ${response.data.length} объявлений загружено');
      print(
        '📊 Meta: currentPage=${response.meta?.currentPage}, totalPages=${response.meta?.lastPage}, itemsPerPage=${response.meta?.perPage}',
      );

      setState(() {
        final newListings = response.data
            .map((advert) => advert.toListing())
            .toList();

        if (isNextPage) {
          // Добавляем новые объявления к существующим
          _listings.addAll(newListings);
        } else {
          // Заменяем список полностью
          _listings = newListings;
        }

        _currentPage = response.meta?.currentPage ?? 1;
        _totalPages = response.meta?.lastPage ?? 1;
        _itemsPerPage = response.meta?.perPage ?? 20;

        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading listings: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadNextPage() {
    if (_currentPage < _totalPages) {
      _loadAdverts(isNextPage: true);
    }
  }

  void _sortListings(Set<String> selectedOptions) {
    String? sort;
    if (selectedOptions.contains('Сначала новые')) sort = 'new';
    if (selectedOptions.contains('Сначала старые')) sort = 'old';
    if (selectedOptions.contains('Сначала дорогие')) sort = 'expensive';
    if (selectedOptions.contains('Сначала дешевые')) sort = 'cheap';

    if (sort != null) {
      _loadAdverts(sort: sort);
    }
  }

  // ============================================================
  //                        BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- FIXED HEADER (не скроллится) ----------------
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 0, bottom: 16),
              child: const Header(),
            ),
            _buildSearchField(context),
            const SizedBox(height: 10),

            _buildLocationAndFilters(),
            // SizedBox(height: 10),

            // _buildCategoryChips(),

            // ---------------- ВСЁ НИЖЕ — СКРОЛЛИТСЯ ----------------
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ---- СКРОЛЛ СТАРТУЕТ ЗДЕСЬ ----
                  SliverToBoxAdapter(child: SizedBox(height: 13)),
                  SliverToBoxAdapter(child: _buildSectionHeader()),
                  SliverToBoxAdapter(child: SizedBox(height: 13)),

                  // ------------ CONTENT ------------
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 80.0,
                            horizontal: 20.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                color: Colors.grey[500],
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Пока тут нет объявлений',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Попробуйте позже или измените критерии поиска',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadAdverts,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Попробовать еще'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_listings.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 80.0,
                            horizontal: 20.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_outlined,
                                color: Colors.grey[500],
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Пока объявлений нет',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'В этой категории пока нет объявлений',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 15,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.70,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => ListingCard(listing: _listings[i]),
                          childCount: _listings.length,
                        ),
                      ),
                    ),
                  // Кнопка загрузки следующей страницы
                  if (!_isLoading &&
                      _errorMessage == null &&
                      _currentPage < _totalPages)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 12.0,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loadNextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Загрузить еще',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ============================================================
  //                      WIDGETS
  // ============================================================

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: textMuted),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2536),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const TextField(
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Поиск",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/home_page/marker-pin.svg',
                color: textMuted,
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 6),
              Text(
                "Мариуполь",
                style: TextStyle(color: textMuted, fontSize: 16),
              ),
              Icon(Icons.keyboard_arrow_down, color: textMuted),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IntermediateFiltersScreen(),
                ),
              );
            },
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/home_page/settings.svg',
                  color: Colors.white,
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  "Фильтры",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildCategoryChips() {
  //   final chipStyle = BoxDecoration(
  //     color: primaryBackground,
  //     borderRadius: BorderRadius.circular(11),
  //     border: Border.all(color: Colors.white),
  //   );

  //   Widget chip(String label, {IconData? icon}) {
  //     return Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  //       decoration: chipStyle,
  //       child: Row(
  //         children: [
  //           Text(label, style: const TextStyle(color: Colors.white)),
  //           if (icon != null) ...[
  //             const SizedBox(width: 6),
  //             Icon(icon, color: Colors.white, size: 18),
  //           ],
  //         ],
  //       ),
  //     );
  //   }

  //   return SizedBox(
  //     height: 40,
  //     child: ListView(
  //       padding: const EdgeInsets.symmetric(horizontal: 12),
  //       scrollDirection: Axis.horizontal,
  //       children: [
  //         chip("Квартиры", icon: Icons.close),
  //         const SizedBox(width: 10),
  //         chip("Новостройка", icon: Icons.keyboard_arrow_down_sharp),
  //         const SizedBox(width: 10),
  //         chip("Количество комнат", icon: Icons.apps),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSectionHeader() {
    // Форматируем заголовок из категории, удаляя переносы строк и очищая текст
    final displayTitle =
        widget.categoryName?.replaceAll('\n', ' ').trim() ?? 'Объявления';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              displayTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildFilterDropdown(
            label: _selectedSortOptions.isEmpty
                ? 'Сначала'
                : _selectedSortOptions.join(', '),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => SelectionDialog(
                  title: 'Сортировать товар',
                  options: const [
                    'Сначала новые',
                    'Сначала старые',
                    'Сначала дорогие',
                    'Сначала дешевые',
                  ],
                  selectedOptions: _selectedSortOptions,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedSortOptions = selected;
                      _sortListings(selected);
                    });
                  },
                  allowMultipleSelection: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 48),
      child: Container(
        height: bottomNavHeight,
        decoration: BoxDecoration(
          color: bottomNavBackground,
          borderRadius: BorderRadius.circular(37.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(homeIconAsset, 0, _selectedIndex),
            _buildNavItem(gridIconAsset, 1, _selectedIndex),
            _buildCenterAdd(2, _selectedIndex),
            _buildNavItem(shoppingCartAsset, 3, _selectedIndex),
            _buildNavItem(messageIconAssetLocal, 4, _selectedIndex),
            _buildNavItem(userIconAsset, 5, _selectedIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String iconPath, int index, int current) {
    final isSelected = index == current;
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () => setState(() => _selectedIndex = index),
      child: Image.asset(
        iconPath,
        width: 28,
        height: 28,
        color: isSelected ? activeIconColor : inactiveIconColor,
      ),
    );
  }

  Widget _buildCenterAdd(int index, int current) {
    final isSelected = index == current;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => setState(() => _selectedIndex = index),
      child: Image.asset(
        plusIconAsset,
        width: 28,
        height: 28,
        color: isSelected ? activeIconColor : inactiveIconColor,
      ),
    );
  }

  Widget _buildFilterDropdown({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.import_export, color: Colors.white, size: 25),
    );
  }
}
