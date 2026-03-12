import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/pages/full_category_screen/real_estate_filtered_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_subfilters_screen.dart';

// ============================================================
// "Полный экран фильтров недвижимости"
// ============================================================

class RealEstateFullFiltersScreen extends StatefulWidget {
  final String selectedCategory;
  final int categoryId; // ID конечной категории для загрузки фильтров
  final String?
  selectedCity; // Город выбранный на промежуточном экране фильтров
  final String? selectedDateSort; // Сортировка по дате (new/old)
  final String? selectedPriceSort; // Сортировка по цене (expensive/cheap)
  final String? selectedSellerType; // Тип продавца (private/business/all)

  const RealEstateFullFiltersScreen({
    super.key,
    required this.selectedCategory,
    this.categoryId = 1, // По умолчанию 1, но должна быть конечная категория
    this.selectedCity,
    this.selectedDateSort,
    this.selectedPriceSort,
    this.selectedSellerType,
  });

  @override
  State<RealEstateFullFiltersScreen> createState() =>
      _RealEstateFullFiltersScreenState();
}

class _RealEstateFullFiltersScreenState
    extends State<RealEstateFullFiltersScreen> {
  String dealType = "sell";

  bool? mortgageYes = null; // По умолчанию неактивна (ни да, ни нет)

  bool? installmentYes = null; // По умолчанию неактивна (ни да, ни нет)

  bool noCommission = false;
  bool exchange = false;
  bool urgent = false;
  bool realtor = false;
  bool buyerOffer = false;
  bool registrySale = false;

  bool isSecondary = true; // По умолчанию вторичка

  bool? isPrivate = null; // По умолчанию неактивна
  String sellerType = ""; // Тип продавца (private/business/all)

  Set<String> selectedCity = {};
  Set<String> selectedStreet = {};
  Set<String> selectedBuildingTypes = {};
  Set<String> selectedWallTypes = {};
  Set<String> selectedLayout = {};
  Set<String> selectedBathrooms = {};
  Set<String> selectedHeating = {};
  Set<String> selectedRenovation = {};
  Set<String> selectedComfort = {};
  Set<String> selectedMultimedia = {};
  Set<String> selectedCommunication = {};
  Set<String> selectedInfrastructure = {};
  Set<String> selectedLandscape = {};
  Set<String> selectedRooms = {};

  // Города загруженные с API (динамически)
  List<String> apiCities = [];
  bool isLoadingCities = false;

  // Улицы загруженные с API (динамически)
  List<String> apiStreets = [];
  bool isLoadingStreets = false;
  String? currentCityId; // ID выбранного города для загрузки улиц

  // Динамические фильтры из API
  List<Attribute> _attributes = [];
  Map<int, dynamic> _selectedValues = {};
  bool _isLoadingFilters = true;
  String? _errorMessage;
  Map<int, TextEditingController> _controllers = {};

  final houseNumberController = TextEditingController();
  final areaController = TextEditingController();
  final kitchenAreaController = TextEditingController();
  final floorsController = TextEditingController();
  final floorController = TextEditingController();
  final constructionMin = TextEditingController();
  final constructionMax = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 RealEstateFullFiltersScreen.initState() called');
    
    // Инициализируем выбранный город если он передан с промежуточного экрана
    if (widget.selectedCity != null && widget.selectedCity!.isNotEmpty) {
      selectedCity = {widget.selectedCity!};
      print(
        '🟢 Город инициализирован в RealEstateFullFiltersScreen: ${widget.selectedCity}',
      );
    }
    // Инициализируем сортировку если она передана с промежуточного экрана
    if (widget.selectedDateSort != null &&
        widget.selectedDateSort!.isNotEmpty) {
      _selectedDateSort = widget.selectedDateSort ?? "";
      print(
        '🟢 Сортировка по дате инициализирована: ${widget.selectedDateSort}',
      );
    }
    if (widget.selectedPriceSort != null &&
        widget.selectedPriceSort!.isNotEmpty) {
      _selectedPriceSort = widget.selectedPriceSort ?? "";
      print(
        '🟢 Сортировка по цене инициализирована: ${widget.selectedPriceSort}',
      );
    }
    // Инициализируем тип продавца если он передан с промежуточного экрана
    if (widget.selectedSellerType != null &&
        widget.selectedSellerType!.isNotEmpty) {
      sellerType = widget.selectedSellerType!;
      if (sellerType == "private") {
        isPrivate = true;
        print('🟢 Тип продавца инициализирован: Частное лицо');
      } else if (sellerType == "business") {
        isPrivate = false;
        print('🟢 Тип продавца инициализирован: Бизнес');
      } else if (sellerType == "all") {
        // Для опции "Все" показываем обе кнопки активными
        print('🟢 Тип продавца инициализирован: Все');
      }
    }
    print('📍 About to call _loadDynamicFilters()');
    _loadDynamicFilters(); // Загружаем динамические фильтры с API
    print('📍 _loadDynamicFilters() called, now loading cities');
    _loadCities(); // Загружаем города с API
    // Загружаем улицы для выбранного города
    if (selectedCity.isNotEmpty) {
      _loadStreetsForCity(selectedCity.first);
    }
    print('✅ initState() completed');
  }

  @override
  void dispose() {
    // Очистка всех текстовых контроллеров
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    houseNumberController.dispose();
    areaController.dispose();
    kitchenAreaController.dispose();
    floorsController.dispose();
    floorController.dispose();
    constructionMin.dispose();
    constructionMax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 19),
              _buildCategoryFilterBlock(),

              const SizedBox(height: 10),
              _buildSortBlock(),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24),
              const SizedBox(height: 0),

              const SizedBox(height: 10),

              // _buildTitle("Выберите улицу"),
              // _buildSelector(
              //   selectedStreet.isEmpty
              //       ? "Выберите улицу"
              //       : selectedStreet.first,
              //   onTap: () {
              //     showDialog(
              //       context: context,
              //       builder: (_) {
              //         return CitySelectionDialog(
              //           title: "Улица",
              //           options: apiStreets.isNotEmpty
              //               ? apiStreets
              //               : const ['Загружаю улицы...'],
              //           selectedOptions: selectedStreet,
              //           onSelectionChanged: (v) =>
              //               setState(() => selectedStreet = v),
              //         );
              //       },
              //     );
              //   },
              //   showArrow: true,
              // ),

              // const SizedBox(height: 16),
              // _buildTitle("Номер дома"),
              // _buildInput("12", houseNumberController),
              // const SizedBox(height: 10),
              // const Divider(color: Colors.white24),

              // // const SizedBox(height: 12),
              // _buildTitle("Вид сделки"),
              // const SizedBox(height: 4),
              // _buildThreeButtons(
              //   labels: const ["Совместная", "Продажа", "Аренда"],
              //   selectedIndex: dealType == "joint"
              //       ? 0
              //       : dealType == "sell"
              //       ? 1
              //       : 2,
              //   onSelect: (i) {
              //     setState(() {
              //       dealType = i == 0
              //           ? "joint"
              //           : i == 1
              //           ? "sell"
              //           : "rent";
              //     });
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => RealEstateSubfiltersScreen(
              //           selectedCategory: widget.selectedCategory,
              //           selectedDealType: dealType,
              //         ),
              //       ),
              //     );
              //   },
              // ),
              // const SizedBox(height: 10),
              // const Divider(color: Colors.white24),
              // const SizedBox(height: 10),

              // Динамические фильтры из API
              _buildDynamicFilters(),

              // const SizedBox(height: 24),
              // const Divider(color: Colors.white24),
              const SizedBox(height: 14),

              // _buildTitle("Частное лицо / Бизнес"),
              // const SizedBox(height: 4),
              // _buildTwoOption(
              //   yes: "Частное лицо",
              //   no: "Бизнес",
              //   selected: isPrivate,
              //   onChange: (v) => setState(() => isPrivate = v),
              // ),

              // const SizedBox(height: 21),
              // const Divider(color: Colors.white24),
              // const SizedBox(height: 21),

              _buildBottomButtons(),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  /// Загружает динамические фильтры с API
  Future<void> _loadDynamicFilters() async {
    try {
      setState(() {
        _isLoadingFilters = true;
        _errorMessage = null;
      });

      final token = TokenService.currentToken;
      print('🔑 Filter load - Token: ${token != null ? 'Present' : 'Missing'}');
      print('📂 Category: ${widget.selectedCategory}');

      // Используем categoryId переданный в конструктор (конечная категория)
      int categoryId = widget.categoryId; // Должна быть конечная категория (is_endpoint=true)
      
      print('🔄 Fetching filters for categoryId: $categoryId (from widget)');

      final response = await ApiService.getListingsFilterAttributes(
        categoryId: categoryId,
        token: token,
      );

      print('� API Response: $response');

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> attributesData = response['data'] as List<dynamic>;
        final attributes = <Attribute>[];

        print('📋 Total attributes in response: ${attributesData.length}');

        for (int i = 0; i < attributesData.length; i++) {
          try {
            final attr = Attribute.fromJson(
              attributesData[i] as Map<String, dynamic>,
            );
            attributes.add(attr);
            print(
              '  ✅ [$i] ID=${attr.id}, Title="${attr.title}", Style="${attr.style}", IsRange=${attr.isRange}, IsMultiple=${attr.isMultiple}',
            );
          } catch (e) {
            print('❌ Error parsing attribute at index $i: $e');
          }
        }

        setState(() {
          _attributes = attributes;
          _isLoadingFilters = false;
        });
        
        // Загружаем сохраненные фильтры для этой категории
        _loadSavedCategoryFilters();

        print('✅ Successfully loaded ${attributes.length} filter attributes');
      } else {
        print('❌ Response success=${response['success']}, data=${response['data']}');
        throw Exception(response['message'] ?? 'Failed to load filters');
      }
    } catch (e) {
      print('❌ Error loading filters: $e');
      print('   Stack trace: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoadingFilters = false;
      });
    }
  }
  
  /// Загружает сохраненные фильтры для текущей категории из Hive
  void _loadSavedCategoryFilters() {
    final savedFilters = HiveService.getCategoryFilters(widget.categoryId);

    if (savedFilters.isEmpty) {
      print('⚠️  Сохраненных фильтров не найдено');
      return;
    }

    print('\n💾 ═══════════════════════════════════════');
    print('💾 _loadSavedCategoryFilters() - RESTORING FILTERS');
    print('💾 Количество ключей: ${savedFilters.length}');

    setState(() {
      // Восстанавливаем атрибуты фильтров
      for (final entry in savedFilters.entries) {
        final key = entry.key;
        final value = entry.value;

        // Пытаемся распарсить ключ как ID атрибута
        final attrId = int.tryParse(key);
        if (attrId != null) {
          dynamic restoredValue = value;
          
          // Если это Map (диапазон) - убеждаемся что 'min' и 'max' это строки
          if (value is Map) {
            final normalizedMap = <String, dynamic>{};
            value.forEach((k, v) {
              normalizedMap[k.toString()] = v?.toString() ?? '';
            });
            restoredValue = normalizedMap;
            print('✅ Restored RANGE атрибут: $key');
          } 
          // Если это List (был Set, конвертирован в List при сохранении)
          else if (value is List) {
            restoredValue = (value as List).cast<String>().toSet();
            print('✅ Restored SET атрибут: $key');
          }
          // Если это Set (выбранные значения)
          else if (value is Set) {
            restoredValue = value;
            print('✅ Restored SET атрибут: $key');
          }
          // Если это boolean
          else if (value is bool) {
            restoredValue = value;
            print('✅ Restored BOOL атрибут: $key');
          }
          // Обычная строка
          else {
            restoredValue = value;
            print('✅ Restored атрибут: $key = $value');
          }
          
          _selectedValues[attrId] = restoredValue;
          
          // Если это диапазон - инициализируем TextEditingControllers
          if (restoredValue is Map) {
            final minKey = attrId * 2;
            final maxKey = attrId * 2 + 1;
            
            final minValue = restoredValue['min']?.toString() ?? '';
            final maxValue = restoredValue['max']?.toString() ?? '';
            
            _controllers[minKey] = TextEditingController(text: minValue);
            _controllers[maxKey] = TextEditingController(text: maxValue);
          }
        }
      }
    });

    print('💾 ═══════════════════════════════════════\n');
  }
  
  /// Сохраняет текущее состояние фильтров для восстановления при следующих посещениях
  Future<void> _saveFilterState() async {
    final stateToSave = <String, dynamic>{};

    // Сохраняем все атрибуты из _selectedValues
    _selectedValues.forEach((key, value) {
      // Пропускаем пустые диапазоны
      if (value is Map) {
        final minEmpty = (value['min']?.toString().isEmpty ?? true);
        final maxEmpty = (value['max']?.toString().isEmpty ?? true);
        if (minEmpty && maxEmpty) return;
      }
      // Пропускаем пустые Set'ы
      if (value is Set && value.isEmpty) return;
      // Пропускаем false boolean'ы
      if (value is bool && !value) return;
      // Пропускаем пустые строки и null
      if (value == '' || value == null) return;

      // ВАЖНО: Конвертируем Set в List для Hive
      if (value is Set) {
        stateToSave[key.toString()] = value.toList();
      } else {
        stateToSave[key.toString()] = value;
      }
    });

    print('\n💾 ═══════════════════════════════════════');
    print('💾 SAVING FILTER STATE TO HIVE');
    print('💾 Items to save: ${stateToSave.length}');
    print('💾 ═══════════════════════════════════════\n');

    await HiveService.saveCategoryFilters(widget.categoryId, stateToSave);
  }

  /// Отображает динамические фильтры
  Widget _buildDynamicFilters() {
    if (_isLoadingFilters) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Colors.lightBlue),
            const SizedBox(height: 12),
            const Text(
              'Загружаю фильтры...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '❌ Ошибка загрузки фильтров:',
              style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _loadDynamicFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.lightBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Попробовать снова',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_attributes.isEmpty) {
      print(
        '🔴 _attributes.isEmpty! _isLoadingFilters=$_isLoadingFilters, _errorMessage=$_errorMessage, total: ${_attributes.length}',
      );
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: const Text(
          'Нет доступных фильтров',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._attributes.map((attr) {
          if (attr.isHidden) {
            return const SizedBox.shrink();
          }

          if (attr.title.contains('Вам предложат цену')) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildFilterField(attr), const SizedBox(height: 10)],
          );
        }).toList(),
      ],
    );
  }

  /// Отображает фильтр в зависимости от его типа
  Widget _buildFilterField(Attribute attr) {
    // Логика определения типа фильтра на основе флагов и документации
    // Приоритет: styleSingle точное совпадение > isSpecialDesign > (isTitleHidden && isMultiple) > isRange > empty > isPopup > isMultiple > Style B1 > else

    print(
      '    🎨 _buildFilterField: ID=${attr.id}, Title="${attr.title}", '
      'values.count=${attr.values.length}, isRange=${attr.isRange}, '
      'isMultiple=${attr.isMultiple}, isSpecialDesign=${attr.isSpecialDesign}, '
      'isTitleHidden=${attr.isTitleHidden}, isPopup=${attr.isPopup}, '
      'styleSingle="${attr.styleSingle ?? ""}"',
    );

    // Style F: Popup диалог с квадратными чекбоксами - определяется по styleSingle="F"
    if (attr.styleSingle == "F" && attr.values.isNotEmpty) {
      print('    -> Rendering as POPUP SELECT CHECKBOXES (Style F) - styleSingle="F"');
      return _buildStyleFPopupFilter(attr);
    }

    // Style C: Да/Нет кнопки (Ипотека, Вид сделки)
    if (attr.isSpecialDesign) {
      print('    -> Rendering as YES/NO BUTTONS (Style C) - isSpecialDesign=true');
      return _buildSpecialDesignFilter(attr);
    }

    // Style I: Чекбоксы без popup (Возможность торга, Без комиссии)
    if (attr.isTitleHidden && attr.isMultiple && attr.values.isNotEmpty) {
      print('    -> Rendering as CHECKBOXES (Style I) - isTitleHidden && isMultiple');
      return _buildCheckboxFilter(attr);
    }

    // Диапазоны от/до (Style A, E, G)
    if (attr.isRange) {
      print('    -> Rendering as RANGE (Style A/E/G) - isRange=true');
      return _buildRangeFilterField(attr);
    }

    // Текстовое поле (Style H)
    if (attr.values.isEmpty) {
      print('    -> Rendering as TEXT INPUT (Style H) - no values');
      return _buildTextFilterField(attr);
    }

    // Style F: Popup диалог с чекбоксами (fallback)
    if (attr.isPopup && attr.values.isNotEmpty) {
      print('    -> Rendering as POPUP SELECT CHECKBOXES (Style F) - isPopup=true');
      return _buildStyleFPopupFilter(attr);
    }

    // Style D: Multiple select (Тип дома)
    if (attr.isMultiple) {
      print('    -> Rendering as MULTIPLE SELECT POPUP (Style D) - isMultiple=true');
      return _buildStyleDMultipleFilter(attr);
    }

    // Style B1: Одиночный чекбокс
    if (attr.values.length == 1 && !attr.isRange && !attr.isSpecialDesign && !attr.isPopup) {
      print('    -> Rendering as SINGLE CHECKBOX (Style B1) - one value only');
      return _buildStyleB1Filter(attr);
    }

    // Single select dropdown
    print('    -> Rendering as DROPDOWN SELECT - default single select');
    return _buildSingleSelectFilter(attr);
  }

  /// Style C: Кнопки Да/Нет для специального дизайна (Ипотека, Вид сделки)
  /// Выводит кнопки для выбора одного из вариантов (Да/Нет, Совместная/Продажа/Аренда и т.д)
  Widget _buildSpecialDesignFilter(Attribute attr) {
    _selectedValues[attr.id] ??= '';
    String selected = _selectedValues[attr.id] is String
        ? _selectedValues[attr.id] as String
        : '';

    // Найти текстовое значение по сохраненному ID для отображения
    String displayText = '';
    if (selected.isNotEmpty) {
      final matchingValue = attr.values.firstWhere(
        (v) => v.id.toString() == selected || v.value == selected,
        orElse: () => const Value(id: 0, value: ''),
      );
      displayText = matchingValue.value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!attr.isTitleHidden) _buildTitle(attr.title),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        Row(
          children: attr.values.asMap().entries.map((entry) {
            final index = entry.key;
            final value = entry.value;
            // Сравниваем по ID, а не по текстовому значению
            final isSelected = selected == value.id.toString();

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < attr.values.length - 1 ? 8.0 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      // 🟢 Сохраняем ID, не текстовое значение!
                      _selectedValues[attr.id] =
                          isSelected ? '' : value.id.toString();
                      print(
                        '✅ Special Design: "${value.value}" → ID=${value.id}',
                      );
                    });
                  },
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? activeIconColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white70,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        value.value,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Style I: Чекбоксы для множественного выбора (Возможность торга, Без комиссии)
  /// Выводит список чекбоксов с возможностью выбрать несколько вариантов
  /// isTitleHidden=true скрывает название фильтра
  Widget _buildCheckboxFilter(Attribute attr) {
    _selectedValues[attr.id] ??= <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Если название не скрыто, показываем его
        if (!attr.isTitleHidden)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(attr.title),
              const SizedBox(height: 8),
            ],
          ),
        // Чекбоксы
        Column(
          children: [
            ...attr.values.asMap().entries.map((entry) {
              final index = entry.key;
              final value = entry.value;
              final valueId = value.id.toString();
              final isChecked = selected.contains(valueId);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      selected.remove(valueId);
                    } else {
                      selected.add(valueId);
                    }
                    _selectedValues[attr.id] = selected;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: index < attr.values.length - 1 ? 12.0 : 0,
                  ),
                  child: Row(
                    children: [
                      CustomCheckbox(
                        value: isChecked,
                        onChanged: (_) {
                          setState(() {
                            if (isChecked) {
                              selected.remove(valueId);
                            } else {
                              selected.add(valueId);
                            }
                            _selectedValues[attr.id] = selected;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value.value,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  /// Текстовое поле
  Widget _buildTextFilterField(Attribute attr) {
    final controller = _controllers.putIfAbsent(
      attr.id,
      () => TextEditingController(text: _selectedValues[attr.id] ?? ''),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!attr.isTitleHidden) _buildTitle(attr.title),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: secondaryBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: attr.title,
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _selectedValues[attr.id] = value;
              });
            },
          ),
        ),
      ],
    );
  }

  /// Диапазон от/до
  Widget _buildRangeFilterField(Attribute attr) {
    _selectedValues[attr.id] ??= {'min': '', 'max': ''};
    Map<String, dynamic> range = _selectedValues[attr.id] is Map
        ? _selectedValues[attr.id] as Map<String, dynamic>
        : {'min': '', 'max': ''};

    final minKey = attr.id * 2;
    final maxKey = attr.id * 2 + 1;

    final minController = _controllers.putIfAbsent(
      minKey,
      () => TextEditingController(text: range['min'] ?? ''),
    );

    final maxController = _controllers.putIfAbsent(
      maxKey,
      () => TextEditingController(text: range['max'] ?? ''),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!attr.isTitleHidden) _buildTitle(attr.title),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildRangeInput('От', minController, (value) {
                setState(() {
                  range['min'] = value;
                  _selectedValues[attr.id] = range;
                });
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRangeInput('До', maxController, (value) {
                setState(() {
                  range['max'] = value;
                  _selectedValues[attr.id] = range;
                });
              }),
            ),
          ],
        ),
      ],
    );
  }

  /// Инпут для диапазона
  Widget _buildRangeInput(
    String hint,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  /// Одиночный выбор dropdown
  Widget _buildSingleSelectFilter(Attribute attr) {
    _selectedValues[attr.id] ??= '';
    String selected = _selectedValues[attr.id] is String
        ? _selectedValues[attr.id] as String
        : '';

    // Найти текстовое значение по сохраненному ID/значению для отображения
    String displayText = selected;
    if (selected.isNotEmpty) {
      final matchingValue = attr.values.firstWhere(
        (v) => v.id.toString() == selected || v.value == selected,
        orElse: () => const Value(id: 0, value: ''),
      );
      displayText = matchingValue.value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!attr.isTitleHidden) _buildTitle(attr.title),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => SelectionDialog(
                title: attr.title,
                options: attr.values.map((v) => v.value).toList(),
                selectedOptions: displayText.isEmpty ? {} : {displayText},
                onSelectionChanged: (newSelected) {
                  setState(() {
                    if (newSelected.isEmpty) {
                      _selectedValues[attr.id] = '';
                    } else {
                      // 🔴 ВАЖНО: Преобразуем текстовое значение в ID!
                      final selectedText = newSelected.first;
                      final matchingValue = attr.values.firstWhere(
                        (v) => v.value == selectedText,
                        orElse: () => const Value(id: 0, value: ''),
                      );
                      if (matchingValue.id != 0) {
                        _selectedValues[attr.id] = matchingValue.id.toString();
                        print(
                          '✅ Single Select: "${selectedText}" → ID=${matchingValue.id}',
                        );
                      } else {
                        _selectedValues[attr.id] = '';
                      }
                    }
                  });
                },
                allowMultipleSelection: false,
              ),
            );
          },
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayText.isEmpty ? 'Выбрать' : displayText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: displayText.isEmpty ? Colors.white70 : Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Style F: Popup с чекбоксами для множественного выбора
  Widget _buildStyleFPopupFilter(Attribute attr) {
    _selectedValues[attr.id] ??= <String>{};
    Set<String> storedIds = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    // Преобразуем сохраненные IDы в текстовые значения для отображения
    List<String> displayValues = <String>[];
    if (storedIds.isNotEmpty) {
      for (var attrValue in attr.values) {
        if (storedIds.contains(attrValue.id.toString())) {
          displayValues.add(attrValue.value);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!attr.isTitleHidden) _buildTitle(attr.title),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            // Преобразуем IDы в текстовые значения для диалога
            Set<String> displaySelected = <String>{};
            if (storedIds.isNotEmpty) {
              for (var attrValue in attr.values) {
                if (storedIds.contains(attrValue.id.toString())) {
                  displaySelected.add(attrValue.value);
                }
              }
            }
            
            showDialog(
              context: context,
              builder: (_) => SelectionDialog(
                title: attr.title,
                options: attr.values.map((v) => v.value).toList(),
                selectedOptions: displaySelected,
                onSelectionChanged: (newSelected) {
                  setState(() {
                    final selectedIds = <String>{};
                    for (var value in attr.values) {
                      if (newSelected.contains(value.value)) {
                        selectedIds.add(value.id.toString());
                      }
                    }
                    _selectedValues[attr.id] = selectedIds;
                  });
                },
                allowMultipleSelection: true,
              ),
            );
          },
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    storedIds.isEmpty ? 'Выбрать' : displayValues.join(', '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: storedIds.isEmpty ? Colors.white70 : Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Style D: Multiple select с popup
  Widget _buildStyleDMultipleFilter(Attribute attr) {
    _selectedValues[attr.id] ??= <String>{};
    Set<String> storedIds = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    // 🔴 FIX: Преобразуем сохраненные IDы в текстовые значения для отображения в диалоге
    // SelectionDialog ожидает текстовых значений (value.value), но мы храним IDы (value.id)
    Set<String> displaySelected = <String>{};
    List<String> displayValues = <String>[]; // Для отображения в поле выбора
    
    if (storedIds.isNotEmpty) {
      for (var attrValue in attr.values) {
        if (storedIds.contains(attrValue.id.toString())) {
          displaySelected.add(attrValue.value);
          displayValues.add(attrValue.value);
          print(
            '   🔄 Display conversion: ID=${attrValue.id} ("${attrValue.value}") is selected',
          );
        }
      }
    }

    print(
      '🎨 StyleD Filter Built: ID=${attr.id}, Title="${attr.title}", Current selected IDs: $storedIds, Display text: $displaySelected',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!attr.isTitleHidden) _buildTitle(attr.title),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            print(
              '🎯 StyleD Dialog opened: ID=${attr.id}, Title="${attr.title}", Current stored IDs: $storedIds',
            );
            showDialog(
              context: context,
              builder: (_) => SelectionDialog(
                title: attr.title,
                options: attr.values.map((v) => v.value).toList(),
                selectedOptions: displaySelected,  // ✅ FIX: Передаем текстовые значения, не IDы
                onSelectionChanged: (newSelected) {
                  print(
                    '✅ StyleD Selection changed: ID=${attr.id}, newSelected=$newSelected',
                  );
                  setState(() {
                    // Преобразуем выбранные значения в их ID
                    final selectedIds = <String>{};
                    for (var value in attr.values) {
                      if (newSelected.contains(value.value)) {
                        print(
                          '   🔄 Converting: "${value.value}" (ID=${value.id}) → added to selectedIds',
                        );
                        selectedIds.add(value.id.toString());
                      }
                    }
                    _selectedValues[attr.id] = selectedIds;
                    print(
                      '✅ StyleD Selection saved: _selectedValues[${attr.id}] = $selectedIds',
                    );
                  });
                },
                allowMultipleSelection: true,
              ),
            );
          },
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    storedIds.isEmpty 
                      ? 'Выбрать' 
                      : displayValues.join(', '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: storedIds.isEmpty ? Colors.white70 : Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Style B1: Одиночный чекбокс без контейнера (Возможен торг)
  /// Выводит просто текст с квадратным чекбоксом справа, без фонового контейнера
  /// Используется для одиночного чекбокса в списке фильтров
  Widget _buildStyleB1Filter(Attribute attr) {
    _selectedValues[attr.id] ??= false;
    bool isChecked =
        _selectedValues[attr.id] == true ||
        _selectedValues[attr.id] == attr.values[0].id.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              // Переключаем между false и ID значения
              _selectedValues[attr.id] = isChecked
                  ? false
                  : attr.values[0].id.toString();
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  attr.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(width: 0),
              // Квадратный чекбокс
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isChecked ? activeIconColor : Colors.transparent,
                  border: Border.all(
                    color: isChecked ? activeIconColor : Colors.white70,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: isChecked
                    ? const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 14),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Загружает города с API (динамически)
  /// Получает все области (регионы) и их города, собирает в единый список
  Future<void> _loadCities() async {
    setState(() => isLoadingCities = true);
    print(
      '🔄 Начинаем загрузку городов с API (real_estate_full_filters_screen)...',
    );

    try {
      // Получаем текущий токен из Hive
      final token = HiveService.getUserData('token') as String?;
      print('🔑 Токен получен: ${token != null ? "✅ YES" : "❌ NO"}');

      // Получаем все области с API
      final regionsResponse = await AddressService.getRegions(token: token);
      final regions = regionsResponse.data;
      print('✅ Загружено ${regions.length} областей');

      if (regions.isEmpty) {
        print('⚠️ Регионов не найдено!');
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

        try {
          // Ищем города по названию региона
          final response = await AddressService.searchAddresses(
            query: regionName,
            token: token,
            types: ['city'],
          );

          // Получаем города из результатов
          for (final result in response.data) {
            if (result.city != null) {
              final cityId = result.city!.id;
              final cityName = result.city!.name;

              if (cityId != null && cityName != null && cityName.isNotEmpty) {
                if (!citiesMap.containsKey(cityName)) {
                  citiesMap[cityName] = {'id': cityId, 'name': cityName};
                }
              }
            }
          }
        } catch (e) {
          print('   ❌ Ошибка при загрузке городов для области $regionName: $e');
        }
      }

      final allCities = citiesMap.values
          .map((c) => c['name'] as String)
          .toList();
      allCities.sort();

      if (mounted && allCities.isNotEmpty) {
        setState(() {
          apiCities = allCities;
          print(
            '✅ apiCities обновлены в real_estate_full_filters_screen (${apiCities.length} городов)',
          );
        });
      } else if (mounted) {
        print('⚠️ Города не найдены');
        setState(() => apiCities = []);
      }
    } catch (e) {
      print('❌ КРИТИЧЕСКАЯ ОШИБКА при загрузке городов: $e');
      if (mounted) {
        setState(() => apiCities = []);
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingCities = false);
      }
    }
  }

  /// Загружает улицы для выбранного города с API
  Future<void> _loadStreetsForCity(String cityName) async {
    setState(() => isLoadingStreets = true);
    print(
      '🔄 Начинаем загрузку улиц для города: $cityName (real_estate_full_filters_screen)...',
    );

    try {
      // Получаем текущий токен из Hive
      final token = HiveService.getUserData('token') as String?;
      print('🔑 Токен получен: ${token != null ? "✅ YES" : "❌ NO"}');

      // Ищем улицы по названию города
      final response = await AddressService.searchAddresses(
        query: cityName,
        token: token,
        types: ['street'],
      );

      print('✅ Загружено ${response.data.length} результатов поиска');

      // Собираем уникальные улицы
      final streetsMap = <String, String>{};

      for (final result in response.data) {
        if (result.street != null && result.street!.name != null) {
          final streetName = result.street!.name!;
          if (!streetsMap.containsKey(streetName)) {
            streetsMap[streetName] = streetName;
          }
        }
      }

      final allStreets = streetsMap.values.toList();
      allStreets.sort(); // Сортируем алфавитно

      if (mounted && allStreets.isNotEmpty) {
        setState(() {
          apiStreets = allStreets;
          print(
            '✅ apiStreets обновлены для города "$cityName" (${apiStreets.length} улиц)',
          );
        });
      } else if (mounted) {
        print('⚠️ Улицы не найдены для города "$cityName"');
        setState(() => apiStreets = []);
      }
    } catch (e) {
      print('❌ КРИТИЧЕСКАЯ ОШИБКА при загрузке улиц: $e');
      print('🔍 Stack: ${StackTrace.current}');
      if (mounted) {
        setState(() => apiStreets = []);
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingStreets = false);
        print('✅ Загрузка улиц завершена (isLoadingStreets = false)');
      }
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 13),
        const Text(
          "Фильтры",
          style: TextStyle(
            fontSize: 18,
            color: Color.fromARGB(255, 255, 255, 255),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            print('\n🔴 ════════════════════════════════════════');
            print('🔴 RESET BUTTON TAPPED');
            print('🔴 ════════════════════════════════════════');
            
            setState(() {
              // Очищаем все фильтры
              _selectedValues.clear();
              _selectedDateSort = "";
              _selectedPriceSort = "";
              selectedCity.clear();
              selectedStreet.clear();
              dealType = "sell";
              isPrivate = null;
              
              print('🔴 Cleared: all filters');
            });
            
            // Удалить сохраненные фильтры для этой категории
            await HiveService.deleteCategoryFilters(widget.categoryId);
            print('🔴 Deleted saved filters from Hive for category 1');
            print('🔴 ════════════════════════════════════════\n');
          },
          child: const Text(
            "Сбросить",
            style: TextStyle(color: Colors.lightBlue, fontSize: 16),
          ),
        ),
      ],
    );
  }

  String _selectedDateSort = ""; // Новые или Старые
  String _selectedPriceSort = ""; // Дорогие или Дешевые

  Widget _buildCategoryFilterBlock() {
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
          widget.selectedCategory,
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
            showDialog(
              context: context,
              builder: (_) {
                return CitySelectionDialog(
                  title: "Выберите город",
                  options: apiCities.isNotEmpty
                      ? apiCities
                      : const ['Загружаю города...'],
                  selectedOptions: selectedCity,
                  onSelectionChanged: (v) {
                    setState(() => selectedCity = v);
                    // Загружаем улицы для выбранного города
                    if (v.isNotEmpty) {
                      _loadStreetsForCity(v.first);
                    }
                  },
                );
              },
            );
          },
          showArrow: true,
        ),
        const SizedBox(height: 16),
        _buildTitle("Выберите категорию"),
        GestureDetector(
          onTap: () => Navigator.pop(context),
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
                        widget.selectedCategory,
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
                  'Изменить',
                  style: TextStyle(color: Colors.lightBlue, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
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
            _sortButton("Новые", "new"),
            const SizedBox(width: 10),
            _sortButton("Старые", "old"),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _sortButton("Дорогие", "expensive"),
            const SizedBox(width: 10),
            _sortButton("Дешевые", "cheap"),
          ],
        ),
      ],
    );
  }

  String _getCategorySubtitle() {
    return 'Недвижимость / ${widget.selectedCategory}';
  }

  Widget _sortButton(String label, String key) {
    final bool isActive = (key == "new" || key == "old")
        ? _selectedDateSort == key
        : _selectedPriceSort == key;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (key == "new" || key == "old") {
              _selectedDateSort = key;
            } else if (key == "expensive" || key == "cheap") {
              _selectedPriceSort = key;
            }
          });
        },
        child: Container(
          height: 35,
          decoration: BoxDecoration(
            color: isActive ? activeIconColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? Colors.transparent : Colors.white,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildPriceBlock() {
    return Row(
      children: [
        Expanded(child: _buildInput("От", areaController)),
        const SizedBox(width: 12),
        Expanded(child: _buildInput("До", areaController)),
      ],
    );
  }

  Widget _buildCheck(String text, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
        ),

        CustomCheckbox(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildToggleYesNo({
    required String labelYes,
    required String labelNo,
    required bool? selected,
    required Function(bool?) onChange,
  }) {
    return Row(
      children: [
        Expanded(
          child: _toggleButton(labelYes, selected == true, () {
            onChange(true);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _toggleButton(labelNo, selected == false, () {
            onChange(false);
          }),
        ),
      ],
    );
  }

  Widget _toggleButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 35,
        decoration: BoxDecoration(
          color: active ? Colors.lightBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? Colors.transparent : Colors.white70,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: active ? Colors.white : Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildThreeButtons({
    required List<String> labels,
    required int selectedIndex,
    required Function(int) onSelect,
  }) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                height: 35,
                margin: EdgeInsets.only(right: i != labels.length - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: selectedIndex == i
                      ? Colors.lightBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selectedIndex == i
                        ? Colors.transparent
                        : Colors.white70,
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selectedIndex == i ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectorDropdown({
    required String label,
    required Set<String> selected,
    required List<String> options,
    required Function(Set<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(label),

        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) {
                return SelectionDialog(
                  title: label,
                  options: options,
                  selectedOptions: selected,
                  onSelectionChanged: onChanged,
                  allowMultipleSelection: true,
                );
              },
            );
          },
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
                  child: Text(
                    selected.isEmpty ? "Выбрать" : selected.join(", "),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRange(
    String label,
    TextEditingController a,
    TextEditingController b,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(label),

        Row(
          children: [
            Expanded(child: _buildInput("От", a)),
            const SizedBox(width: 12),
            Expanded(child: _buildInput("До", b)),
          ],
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: label,
            hintStyle: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoOption({
    required String yes,
    required String no,
    required bool? selected,
    required Function(bool) onChange,
  }) {
    return Row(
      children: [
        Expanded(
          child: _toggleButton(yes, selected == true, () => onChange(true)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _toggleButton(no, selected == false, () => onChange(false)),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size.fromHeight(51),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            onPressed: () async {
              // Сохраняем текущие фильтры в Hive
              await _saveFilterState();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Фильтры сохранены')),
                );
              }
            },
            child: const Text(
              "Сохранить настройки фильтра",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white70),
              minimumSize: const Size.fromHeight(51),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // TODO: Показать на карте
            },
            child: const Text(
              "Показать на карте",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              minimumSize: const Size.fromHeight(51),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              // Сохраняем фильтры перед переходом на экран результатов
              await _saveFilterState();
              
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RealEstateFilteredScreen(
                      selectedCategory: widget.selectedCategory,
                      categoryId: widget.categoryId,
                      selectedCity: widget.selectedCity,
                    ),
                  ),
                );
              }
            },
            child: const Text(
              "Показать",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
