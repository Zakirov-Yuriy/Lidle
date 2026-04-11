import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/full_category_screen/real_estate_full_subcategories_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_full_filters_screen.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/selectable_button.dart';
import 'package:lidle/core/logger.dart';

// ============================================================
// "Промежуточный экран фильтров"
// ============================================================

class IntermediateFiltersScreen extends StatefulWidget {
  static const String routeName = "/intermediate-filters";

  final String?
  displayTitle; // Динамически подтягиваемый заголовок из real_estate_listings_screen
  final int? catalogId; // ID каталога для загрузки категорий (Недвижимость=1, Работа=2 и т.д.)

  const IntermediateFiltersScreen({super.key, this.displayTitle, this.catalogId});

  @override
  State<IntermediateFiltersScreen> createState() =>
      _IntermediateFiltersScreenState();
}

class _IntermediateFiltersScreenState extends State<IntermediateFiltersScreen> {
  String selectedDateSort = ""; // Новые или Старые
  String selectedPriceSort = ""; // Дорогие или Дешевые

  String selectedCurrency = "uah";

  String sellerType = "";

  String viewMode = "gallery";

  // Выбранная категория и тип апартамента
  String? selectedSubcategory;
  int selectedSubcategoryId = 1; // По умолчанию используем 1, но переписывается при выборе
  String? selectedApartmentType;
  bool showCategoryError = false; // Показывает ошибку если категория не выбрана

  Set<String> selectedCities = {};
  Set<String> selectedStreet = {};
  Set<String> selectedCity = {};

  // Города загруженные с API (динамически)
  List<String> apiCities = [];
  bool isLoadingCities = false;
  
  // Категории недвижимости для маппинга названия на ID
  List<dynamic> realEstateCategories = [];
  
  bool _isNavigating = false; // Флаг для предотвращения множественных навигаций

  final TextEditingController priceFrom = TextEditingController();
  final TextEditingController priceTo = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with empty list, will be populated from API
    apiCities = [];
    
    _loadCities(); // Load cities from API
    _loadRealEstateCategories(); // Load real estate categories
  }

  @override
  void dispose() {
    priceFrom.dispose();
    priceTo.dispose();
    super.dispose();
  }

  /// Загружает категории недвижимости для маппинга имён на IDs
  Future<void> _loadRealEstateCategories() async {
    try {
      final token = TokenService.currentToken;
      final catalog = await ApiService.getCatalog(1, token: token); // catalogId = 1 для Недвижимости
      
      if (mounted) {
        setState(() {
          realEstateCategories = catalog.categories;
          log.d('Loaded ${realEstateCategories.length} real estate categories');
        });
      }
    } catch (e) {
      log.d('Error loading real estate categories: $e');
    }
  }

  /// Находит ID категории по её названию
  int _findCategoryIdByName(String categoryName) {
    try {
      for (var cat in realEstateCategories) {
        // Пытаемся получить id и name обычным способом
        try {
          // Если это Map
          if (cat is Map) {
            if (cat['name'] == categoryName) {
              return cat['id'] as int;
            }
          } else {
            // Если это объект с полями id и name
            if (cat.name == categoryName) {
              return cat.id as int;
            }
          }
        } catch (e) {
          // Пропускаем если не удалось обработать элемент
          continue;
        }
      }
    } catch (e) {
      log.d('Error finding category ID: $e');
    }
    return 1; // Fallback к ID=1 если не найдено
  }

  /// Загружает города с API (динамически)
  /// Получает все области (регионы) и их города, собирает в единый список
  Future<void> _loadCities() async {
    setState(() => isLoadingCities = true);
    log.d('🔄 Начинаем загрузку городов с API...');
    
    try {
      // Получаем текущий токен из Hive
      final token = HiveService.getUserData('token') as String?;
      log.d('🔑 Токен получен: ${token != null ? "✅ YES ($token)" : "❌ NO"}');
      
      // Получаем все области с API
      final regionsResponse = await AddressService.getRegions(token: token);
      final regions = regionsResponse.data;
      log.d('✅ Загружено ${regions.length} областей');
      
      if (regions.isEmpty) {
        log.d('⚠️ Регионов не найдено!');
        if (mounted) {
          setState(() => apiCities = []);
        }
        return;
      }
      
      // Для каждой области получаем города
      final citiesMap = <String, Map<String, dynamic>>{};
      
      for (int i = 0; i < regions.length; i++) {
        final region = regions[i];
        final regionName = region.name ?? 'Неизвестная область';
        
        log.d('📍 [$i/${regions.length}] Обрабатываем область: $regionName');
        
        try {
          // Ищем города по названию региона
          log.d('   🔍 Запрашиваем города для поиска по названию: "$regionName"...');
          
          final response = await AddressService.searchAddresses(
            query: regionName,
            token: token,
            types: ['city'],
            filters: region.id != null ? {'main_region_id': region.id} : null,
          );
          
          log.d('   ✅ Получено ${response.data.length} результатов поиска');
          
          // Получаем города из результатов
          int addedCount = 0;
          for (final result in response.data) {
            if (result.city != null) {
              final cityId = result.city!.id;
              final cityName = result.city!.name;
              
              if (cityId != null && cityName != null && cityName.isNotEmpty) {
                // Используем имя города как ключ для избежания дубликатов
                if (!citiesMap.containsKey(cityName)) {
                  citiesMap[cityName] = {
                    'id': cityId,
                    'name': cityName,
                  };
                  addedCount++;
                  log.d('   → Добавлен город: $cityName (id: $cityId)');
                }
              }
            }
          }
          log.d('   → Добавлено $addedCount городов в итоговый список');
        } catch (e) {
          log.d('   ❌ Ошибка при загрузке городов для области $regionName: $e');
        }
      }

      var allCities = citiesMap.values.map((c) => c['name'] as String).toList();
      log.d('✅ ИТОГО загружено уникальных городов с API: ${allCities.length}');
      log.d('✅ ИТОГО города после объединения: ${allCities.length} (дедупликация через Set)');

      // Сортируем города для удобства
      allCities.sort();

      if (mounted && allCities.isNotEmpty) {
        setState(() {
          apiCities = allCities;
          log.d('✅ apiCities обновлены в состояние (${apiCities.length} городов)');
          log.d('🏙️ apiCities final value: ${apiCities.length} cities - $apiCities');
        });
      } else if (mounted) {
        log.d('⚠️ Города не найдены (allCities.length = ${allCities.length})');
        setState(() => apiCities = []);
      }
    } catch (e) {
      log.d('❌ КРИТИЧЕСКАЯ ОШИБКА при загрузке городов: $e');
      log.d('🔍 Stack: ${StackTrace.current}');
      if (mounted) {
        setState(() => apiCities = []);
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingCities = false);
        log.d('✅ Загрузка городов завершена (isLoadingCities = false)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryFilterBlock(),

                    const SizedBox(height: 18),
                    _buildSortBlock(),

                    const SizedBox(height: 18),
                    _buildSectionTitle("Частное лицо / Бизнес"),
                    const SizedBox(height: 18),
                    _buildSellerTypeButtons(),
                  ],
                ),
              ),
            ),

            _buildApplyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 5),
              Text(
                "Фильтры",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(width: 16),

              const Spacer(),

              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDateSort = "";
                    selectedPriceSort = "";
                    selectedCurrency = "uah";
                    selectedCities.clear();
                    selectedCity.clear();
                    priceFrom.clear();
                    priceTo.clear();
                    sellerType = "";
                    viewMode = "gallery";
                    selectedSubcategory = null;
                    showCategoryError = false;
                  });
                },
                child: const Text(
                  "Сбросить",
                  style: TextStyle(color: activeIconColor, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSellerTypeButtons() {
    return Column(
      children: [
        Row(
          children: [
            Flexible(
              flex: 1,
              child: _choiceButton(
                text: "Все",
                selected: sellerType == "all",
                onTap: () => setState(() => sellerType = "all"),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 2,
              child: _choiceButton(
                text: "Частное лицо",
                selected: sellerType == "private",
                onTap: () => setState(() => sellerType = "private"),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 2,
              child: _choiceButton(
                text: "Бизнес",
                selected: sellerType == "business",
                onTap: () => setState(() => sellerType = "business"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Вспомогательный метод для создания кнопки выбора типа продавца
  /// Стилизован согласно filters_screen.dart
  Widget _choiceButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected ? activeIconColor : Colors.transparent;
    final fg = selected ? Colors.white : Colors.white70;
    final border = selected
        ? Border.all(color: Colors.transparent)
        : Border.all(color: const Color(0x80FFFFFF));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 35,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      color: primaryBackground,
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBackground,
            minimumSize: const Size.fromHeight(51),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: activeIconColor),
            ),
          ),
          onPressed: () {
            // Проверяем что категория выбрана
            if (selectedSubcategory == null || selectedSubcategory!.isEmpty) {
              setState(() {
                showCategoryError = true;
              });
              return; // Прерываем навигацию
            }
            
            // Переход на экран фильтра с подтянутыми данными из промежуточного фильтра
            final selectedCityName = selectedCity.isNotEmpty ? selectedCity.first : null;
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RealEstateFullFiltersScreen(
                  selectedCategory:
                      selectedSubcategory ??
                      widget.displayTitle ??
                      'Недвижимость',
                  categoryId: selectedSubcategoryId,
                  selectedCity: selectedCityName,
                  selectedDateSort: selectedDateSort.isNotEmpty ? selectedDateSort : null,
                  selectedPriceSort: selectedPriceSort.isNotEmpty ? selectedPriceSort : null,
                  selectedSellerType: sellerType.isNotEmpty ? sellerType : null,
                ),
              ),
            );
          },
          child: const Text(
            "Применить",
            style: TextStyle(
              color: activeIconColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// ════════════════════════════════════════════════════════════
  /// Методы-помощники для блока категорий (как в real_estate_full_filters_screen.dart)
  /// ════════════════════════════════════════════════════════════

  Widget _buildCategoryFilterBlock() {
    // Форматируем заголовок: убираем переносы строк и очищаем текст
    final displayCategoryTitle =
        widget.displayTitle?.replaceAll('\n', ' ').trim() ?? 'Недвижимость';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Категории",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildSelectedBox(
          displayCategoryTitle,
          showRemove: false,
          backgroundColor: const Color(0xFF6B7280),
          textColor: Colors.black,
          fitWidth: true,
          verticalPadding: 6,
        ),
        const SizedBox(height: 21),
        _buildTitle("Выберите город"),
        _buildSelector(
          selectedCity.isEmpty ? "Выберите город" : selectedCity.first,
          onTap: () {
            final citiesToShow = apiCities;
            log.d('\n📱 Открытие диалога выбора города:');
            log.d('   - apiCities.length: ${apiCities.length}');
            log.d('   - citiesToShow.length: ${citiesToShow.length}');
            showDialog(
              context: context,
              builder: (_) {
                return CitySelectionDialog(
                  title: "Выберите город",
                  options: citiesToShow,
                  selectedOptions: selectedCity,
                  onSelectionChanged: (v) => setState(() => selectedCity = v),
                );
              },
            );
          },
          showArrow: true,
        ),
        const SizedBox(height: 16),
        _buildTitle("Выберите категорию"),
        GestureDetector(
          onTap: () async {
            // Защита от множественных нажатий
            if (_isNavigating) {
              log.d('🛑 Already navigating to category selection, ignoring tap');
              return;
            }
            
            _isNavigating = true;
            
            try {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RealEstateFullSubcategoriesScreen(
                    catalogId: widget.catalogId ?? 1, // Передаём ID каталога, по умолчанию 1 (Недвижимость)
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  // result теперь может быть либо String (для категорий без детей), либо Map {'name': String, 'id': int}
                  if (result is Map) {
                    selectedSubcategory = result['name'] as String?;
                    selectedSubcategoryId = result['id'] as int? ?? 1;
                    log.d('Selected subcategory: ${result['name']} (ID: ${result['id']})');
                    showCategoryError = false;
                  } else if (result is String) {
                    // Fallback для старого формата
                    selectedSubcategory = result;
                    selectedSubcategoryId = _findCategoryIdByName(result);
                    log.d('Selected subcategory: $result (ID: $selectedSubcategoryId)');
                    showCategoryError = false;
                  }
                });
              }
            } finally {
              _isNavigating = false;
            }
          },
          child: Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedSubcategory ??
                            widget.displayTitle?.replaceAll('\n', ' ').trim() ??
                            'Недвижимость',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getCategorySubtitle(),
                        style: const TextStyle(
                          color: Color(0xFF7A7A7A),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Выбрать',
                  style: TextStyle(color: Colors.lightBlue, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        // Сообщение об ошибке если категория не выбрана
        if (showCategoryError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Выберите категорию',
              style: const TextStyle(
                color: Color(0xFFFF4444), // Красный цвет как на скриншоте
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  String _getCategorySubtitle() {
    final categoryTitle =
        widget.displayTitle?.replaceAll('\n', ' ').trim() ?? 'Недвижимость';
    final subcategoryTitle = selectedSubcategory ?? categoryTitle;
    return '$categoryTitle / $subcategoryTitle';
  }

  Widget _buildTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSelectedBox(
    String text, {
    required bool showRemove,
    VoidCallback? onRemove,
    Color? backgroundColor,
    Color? textColor,
    bool fitWidth = false,
    double verticalPadding = 12,
  }) {
    return Container(
      width: fitWidth ? null : double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? secondaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: fitWidth ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(text, style: TextStyle(color: textColor ?? Colors.white)),
          if (showRemove)
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildSelector(
    String text, {
    VoidCallback? onTap,
    bool showArrow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white)),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Сортировка",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _sortButton("Новые", "new", "date"),
            const SizedBox(width: 10),
            _sortButton("Старые", "old", "date"),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _sortButton("Дорогие", "expensive", "price"),
            const SizedBox(width: 10),
            _sortButton("Дешевые", "cheap", "price"),
          ],
        ),
      ],
    );
  }

  Widget _sortButton(String label, String value, String sortType) {
    final isActive = sortType == "date"
        ? selectedDateSort == value
        : selectedPriceSort == value;

    return Expanded(
      child: SelectableButton(
        text: label,
        isActive: isActive,
        onTap: () {
          setState(() {
            if (sortType == "date") {
              selectedDateSort = selectedDateSort == value ? "" : value;
            } else {
              selectedPriceSort = selectedPriceSort == value ? "" : value;
            }
          });
        },
        maxWidth: double.infinity,
      ),
    );
  }
}
