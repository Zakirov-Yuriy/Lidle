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
  final int? categoryId; // 🎯 ПРЯМОЙ ID категории (чтобы не искать по имени)
  final String? catalogName; // 🎯 Название каталога для отображения в фильтрах (Недвижимость, Автомобили и т.д.)

  const IntermediateFiltersScreen({super.key, this.displayTitle, this.catalogId, this.categoryId, this.catalogName});

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
  bool showCityError = false; // Показывает ошибку если город не выбран

  Set<String> selectedCities = {};
  Set<String> selectedStreet = {};
  Set<String> selectedCity = {};

  // Города загруженные с API (динамически)
  List<String> apiCities = [];
  bool isLoadingCities = false;
  
  // Категории недвижимости для маппинга названия на ID
  List<dynamic> realEstateCategories = [];
  
  bool _isNavigating = false; // Флаг для предотвращения множественных навигаций
  
  // Для прокрутки к ошибкам
  late ScrollController _scrollController;

  final TextEditingController priceFrom = TextEditingController();
  final TextEditingController priceTo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Initialize with empty list, will be populated from API
    apiCities = [];
    
    // 🎯 ЕСЛИ categoryId передан напрямую, используем его сразу (без поиска по имени)
    if (widget.categoryId != null) {
      selectedSubcategoryId = widget.categoryId!;
      log.d('✅ Using direct categoryId from parameter: ${widget.categoryId}');
    }
    
    // 🎯 ИНИЦИАЛИЗИРУЕМ КАТЕГОРИЮ из displayTitle (передаётся из real_estate_listings_screen)
    // Это исправляет проблему: визуально категория была видна, но валидация падала
    if (widget.displayTitle != null && widget.displayTitle!.isNotEmpty) {
      selectedSubcategory = widget.displayTitle!.replaceAll('\n', ' ').trim();
      log.d('✅ INITIALIZED selectedSubcategory from displayTitle: "$selectedSubcategory"');
      // ⏳ selectedSubcategoryId будет найден ПОСЛЕ загрузки категорий в _loadRealEstateCategories()
    }
    
    _loadCities(); // Load cities from API
    _loadRealEstateCategories(); // Load real estate categories - ВАЖНО: это найдёт ID для категории!
  }

  @override
  void dispose() {
    priceFrom.dispose();
    priceTo.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Загружает категории недвижимости для маппинга имён на IDs
  Future<void> _loadRealEstateCategories() async {
    try {
      final token = TokenService.currentToken;
      log.d('🔑 Loading categories with token: ${token != null ? 'YES' : 'NO'}');
      final catalogIdToLoad = widget.catalogId ?? 1; // 🎯 Используем передаваемый catalogId, по умолчанию 1
      log.d('📦 Загружаем каталог ID=$catalogIdToLoad');
      final catalog = await ApiService.getCatalog(catalogIdToLoad, token: token);
      
      if (mounted) {
        setState(() {
          realEstateCategories = catalog.categories;
          log.d('\n📂 ════════════════════════════════════════════════════');
          log.d('📂 Loaded ${realEstateCategories.length} MAIN categories');
          log.d('📂 All available MAIN categories:');
          for (int i = 0; i < realEstateCategories.length; i++) {
            final cat = realEstateCategories[i];
            try {
              if (cat is Map) {
                log.d('   [$i] ID=${cat['id']}, Name="${cat['name']}", IsEndpoint=${cat['is_endpoint']}, Children=${cat['children']?.length ?? 0}');
              } else {
                log.d('   [$i] ID=${cat.id}, Name="${cat.name}", IsEndpoint=${cat.isEndpoint}, Children=${cat.children?.length ?? 0}');
              }
            } catch (e) {
              log.d('   [$i] Error parsing: $e');
            }
          }
          log.d('📂 ════════════════════════════════════════════════════\n');
          
          // 🎯 ВАЖНО: Теперь когда категории загружены, найдём ID для selectedSubcategory
          // Но только если categoryId не был передан напрямую в конструктор
          if (widget.categoryId == null) {
            if (selectedSubcategory != null && selectedSubcategory!.isNotEmpty) {
              log.d('🔍 Looking for category: "$selectedSubcategory"');
              selectedSubcategoryId = _findCategoryIdByName(selectedSubcategory!);
              log.d('✅ Found category ID: "$selectedSubcategory" → ID=$selectedSubcategoryId');
            } else {
              log.d('⚠️ selectedSubcategory is null or empty, using default ID=1');
            }
          } else {
            log.d('✅ categoryId already set from parameter: $selectedSubcategoryId');
          }
        });
      }
    } catch (e) {
      log.d('❌ Error loading real estate categories: $e');
    }
  }

  /// Находит ID категории по её названию (ищет в главных категориях и подкатегориях)
  int _findCategoryIdByName(String categoryName) {
    log.d('\n🔎 ════════════════════════════════════════════════════');
    log.d('🔎 _findCategoryIdByName() searching for: "$categoryName"');
    log.d('🔎 Total MAIN categories to search: ${realEstateCategories.length}');
    
    try {
      // 1️⃣ Сначала ищем в главных категориях
      for (int idx = 0; idx < realEstateCategories.length; idx++) {
        var cat = realEstateCategories[idx];
        try {
          String mainName = '';
          int mainId = 0;
          bool isEndpoint = false;
          List<dynamic> children = [];
          
          // Если это Map
          if (cat is Map) {
            mainName = cat['name']?.toString() ?? '';
            mainId = cat['id'] ?? 0;
            isEndpoint = cat['is_endpoint'] ?? false;
            children = cat['children'] ?? [];
          } else {
            // Если это объект
            mainName = cat.name?.toString() ?? '';
            mainId = cat.id ?? 0;
            isEndpoint = cat.isEndpoint ?? false;
            children = cat.children ?? [];
          }
          
          log.d('   [$idx] MAIN: name="$mainName" (ID=$mainId, isEndpoint=$isEndpoint, childrenCount=${children.length})');
          
          // Проверяем главную категорию
          if (mainName == categoryName && isEndpoint) {
            log.d('   ✅ MATCH in MAIN category!');
            log.d('🔎 ════════════════════════════════════════════════════\n');
            return mainId;
          }
          
          // 2️⃣ Если есть дети - ищем в подкатегориях
          if (children.isNotEmpty) {
            log.d('      Searching in ${children.length} sub-categories...');
            for (int cidx = 0; cidx < children.length; cidx++) {
              var child = children[cidx];
              try {
                String childName = '';
                int childId = 0;
                bool childIsEndpoint = false;
                
                if (child is Map) {
                  childName = child['name']?.toString() ?? '';
                  childId = child['id'] ?? 0;
                  childIsEndpoint = child['is_endpoint'] ?? false;
                } else {
                  childName = child.name?.toString() ?? '';
                  childId = child.id ?? 0;
                  childIsEndpoint = child.isEndpoint ?? false;
                }
                
                log.d('         [$cidx] SUB: name="$childName" (ID=$childId, isEndpoint=$childIsEndpoint) → ${childName == categoryName ? '✅ MATCH!' : '❌ no match'}');
                
                if (childName == categoryName && childIsEndpoint) {
                  log.d('   ✅ MATCH in SUB-category!');
                  log.d('🔎 ════════════════════════════════════════════════════\n');
                  return childId;
                }
              } catch (e) {
                log.d('         [$cidx] Error parsing sub-category: $e');
              }
            }
          }
        } catch (e) {
          log.d('   [$idx] Error parsing main category: $e');
          continue;
        }
      }
    } catch (e) {
      log.d('❌ Error in _findCategoryIdByName: $e');
    }
    
    log.d('❌ Category "$categoryName" NOT FOUND in MAIN or SUB categories! Returning default ID=1');
    log.d('🔎 ════════════════════════════════════════════════════\n');
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
                controller: _scrollController,
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
                    showCityError = false;
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
            // Очищаем предыдущие ошибки
            setState(() {
              showCategoryError = false;
              showCityError = false;
            });
            
            // Проверяем валидность полей (без ранних возвратов, чтобы показать все ошибки)
            bool hasErrors = false;
            
            // Проверяем что категория выбрана
            if (selectedSubcategory == null || selectedSubcategory!.isEmpty) {
              log.d('🔴 Ошибка валидации: категория не выбрана!');
              setState(() {
                showCategoryError = true;
              });
              hasErrors = true;
            }
            
            // Проверяем что город выбран
            if (selectedCity.isEmpty) {
              log.d('🔴 Ошибка валидации: город не выбран!');
              setState(() {
                showCityError = true;
              });
              log.d('✅ showCityError установлен в true');
              hasErrors = true;
            }
            
            // Если есть ошибки, прокручиваем вверх и выходим
            if (hasErrors) {
              // Прокручиваем вверх к ошибкам (больше расстояния для видимости обеих)
              Future.delayed(const Duration(milliseconds: 150), () {
                _scrollController.animateTo(
                  _scrollController.position.minScrollExtent,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              });
              return; // Прерываем навигацию
            }
            
            // Переход на экран фильтра с подтянутыми данными из промежуточного фильтра
            final selectedCityName = selectedCity.isNotEmpty ? selectedCity.first : null;
            
            // 🎯 ВАЛИДАЦИЯ: Если пришли с основной категорией (catalogId), проверяем что выбрана подкатегория
            if (widget.categoryId == null && widget.catalogId != null && selectedSubcategoryId == 1) {
              log.w('⚠️  VALIDATION FAILED: пользователь не выбрал подкатегорию');
              setState(() {
                showCategoryError = true;
              });
              return; // Прерываем навигацию
            }
            
            log.d('\n🟢 ════════════════════════════════════════════════════');
            log.d('🟢 APPLYING FILTERS - NavigatingTo RealEstateFullFiltersScreen');
            log.d('🟢 Parameters:');
            log.d('   selectedCategory: "$selectedSubcategory"');
            log.d('   categoryId: $selectedSubcategoryId ⚠️ CHECK THIS!');
            log.d('   selectedCity: "$selectedCityName"');
            log.d('   selectedDateSort: "$selectedDateSort"');
            log.d('   selectedPriceSort: "$selectedPriceSort"');
            log.d('   selectedSellerType: "$sellerType"');
            log.d('🟢 ════════════════════════════════════════════════════\n');
            
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
                  catalogName: widget.catalogName ?? 'Недвижимость', // 🎯 Передаём название каталога
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
                  onSelectionChanged: (v) => setState(() {
                    selectedCity = v;
                    showCityError = false;
                  }),
                );
              },
            );
          },
          showArrow: true,
        ),
        // Сообщение об ошибке если город не выбран
        if (showCityError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Выберите город',
              style: const TextStyle(
                color: Color(0xFFFF4444), // Красный цвет как на скриншоте
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        SizedBox(height: showCityError ? 24 : 16),
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
              // 🎯 Определяем какой catalogId использовать при открытии диалога
              // Если пришли с конкретной категории (widget.categoryId != null) и 
              // знаем из какого каталога она (widget.catalogId), используем его
              // Если пришли с основной категории (catalogId известен), используем его
              final catalogIdForDialog = widget.catalogId ?? 1;
              
              log.d('📢 Opening category selection dialog for catalogId=$catalogIdForDialog');
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RealEstateFullSubcategoriesScreen(
                    catalogId: catalogIdForDialog, // 🎯 Теперь используем правильный catalogId
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
