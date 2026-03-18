import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/j_calendar/j_calendar_widget.dart';
import 'package:lidle/widgets/components/k_calendar/k_calendar_widget.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/models/filter_models.dart';

// ============================================================
// "Динамический экран фильтров для листинга объявлений"
// ============================================================
//
// ЛОГИКА ОТОБРАЖЕНИЯ ФИЛЬТРОВ (на основе документации стилей):
//
// ┌─────────────────────────────────────────────────────────────────┐
// │ Тип фильтра    │ Флаги                    │ Стиль │ Примеры      │
// ├─────────────────────────────────────────────────────────────────┤
// │ Кнопки Да/Нет  │ isSpecialDesign=true     │   C   │ Ипотека      │
// │ Чекбоксы       │ isTitleHidden && isMulti │   I   │ Возм. торга  │
// │ Диапазон от/до │ isRange=true             │ A/E/G │ Цена, Этаж   │
// │ Текстовое поле │ values.isEmpty           │   H   │ Название ЖК  │
// │ Popup checkbox │ isPopup=true             │   F   │ Тип сделки   │
// │ Popup checkbox │ isMultiple=true          │   D   │ Тип дома     │
// └─────────────────────────────────────────────────────────────────┘
//
// ВАЖНО: Style F и Style D - оба используют popup с чекбоксами для множественного выбора
// Отличие: F определяется через isPopup=true, D через isMultiple=true
// Все методы поддерживают isTitleHidden флаг для скрытия названия поля.

class RealEstateListingsFilterScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final Map<String, dynamic>? appliedFilters;

  const RealEstateListingsFilterScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.appliedFilters,
  });

  @override
  State<RealEstateListingsFilterScreen> createState() =>
      _RealEstateListingsFilterScreenState();
}

class _RealEstateListingsFilterScreenState
    extends State<RealEstateListingsFilterScreen> {
  // =============== Filter State ===============
  List<Attribute> _attributes = [];
  Map<int, dynamic> _selectedValues = {};
  bool _isLoading = true;
  String? _errorMessage;
  Map<int, TextEditingController> _controllers = {};

  // =============== Address Data ===============
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _cities = [];
  Set<String> _selectedRegion = {};
  Set<String> _selectedCity = {};
  // ignore: unused_field
  int? _selectedRegionId;
  int? _selectedCityId;
  bool _citiesLoading = false; // Индикатор загрузки городов

  // =============== Sort Options ===============
  String? _selectedDateSort;
  String? _selectedPriceSort;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadRegions();
    // Загрузить применённые фильтры если они есть
    if (widget.appliedFilters != null) {
      _loadAppliedFilters();
    }
    // Загрузить сохраненные фильтры для этой категории
    _loadSavedCategoryFilters();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Получить токен из хранилища
      final token = TokenService.currentToken;

      print('🔑 Filter load - Token: ${token != null ? 'Present' : 'Missing'}');
      print('📥 Loading filters for category: ${widget.categoryId}');

      // Получить фильтры для категории через API
      final response = await ApiService.getListingsFilterAttributes(
        categoryId: widget.categoryId,
        token: token,
      );

      print('📊 API Response: $response');

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
          _isLoading = false;
        });

        print('✅ Successfully loaded ${attributes.length} filter attributes');
      } else {
        print(
          '❌ Response success=${response['success']}, data=${response['data']}',
        );
        throw Exception(response['message'] ?? 'Failed to load filters');
      }
    } catch (e) {
      print('❌ Error loading filters: $e');
      print('   Stack trace: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadAppliedFilters() {
    if (widget.appliedFilters == null) return;

    print('\n🔄 ═══════════════════════════════════════');
    print('🔄 _loadAppliedFilters() - RESTORING FILTERS');
    print('🔄 Applied filters count: ${widget.appliedFilters!.length}');
    print('🔄 ═══════════════════════════════════════');

    // Восстановить ранее выбранные значения
    widget.appliedFilters!.forEach((key, value) {
      try {
        // Восстановить city_id если он есть
        if (key == 'city_id' && value is int) {
          _selectedCityId = value;
          // Найти имя города по ID для отображения
          for (final city in _cities) {
            if (city['id'] == value) {
              _selectedCity = {city['name'] as String};
              print('✅ Restored city: ${city['name']} (ID: $value)');
              break;
            }
          }
        }
        // Восстановить атрибуты по числовым ID
        else {
          final attrId = int.tryParse(key);
          if (attrId != null) {
            _selectedValues[attrId] = value;
            print('✅ Restored attribute: $key = $value');
          }
        }
      } catch (e) {
        print('⚠️  Error loading filter: $e');
      }
    });

    print('🔄 ═══════════════════════════════════════\n');
  }

  /// Загружает сохраненные фильтры для текущей категории из Hive
  void _loadSavedCategoryFilters() {
    final savedFilters = HiveService.getCategoryFilters(widget.categoryId);

    if (savedFilters.isEmpty) {
      print('⚠️  Сохраненных фильтров для категории ${widget.categoryId} не найдено');
      return;
    }

    print('\n💾 ═══════════════════════════════════════');
    print('💾 _loadSavedCategoryFilters() - RESTORING SAVED FILTERS');
    print('💾 Категория: ${widget.categoryId}');
    print('💾 Количество ключей: ${savedFilters.length}');
    
    savedFilters.forEach((key, value) {
      print('   Ключ: "$key" (type=${key.runtimeType})');
      if (value is Map) {
        print('   └─ Value: Map (${value.length} items) -> ${value.toString()}');
      } else if (value is List) {
        print('   └─ Value: List (${value.length} items) -> ${value.toString()}');
      } else if (value is Set) {
        print('   └─ Value: Set (${value.length} items) -> ${value.toString()}');
      } else {
        print('   └─ Value: ${value.runtimeType} -> $value');
      }
    });
    print('💾 ═══════════════════════════════════════');

    setState(() {
      // Восстанавливаем сортировку
      if (savedFilters.containsKey('sort_date')) {
        _selectedDateSort = savedFilters['sort_date'] as String?;
        print('✅ Восстановлена сортировка по дате: $_selectedDateSort');
      }
      if (savedFilters.containsKey('sort_price')) {
        _selectedPriceSort = savedFilters['sort_price'] as String?;
        print('✅ Восстановлена сортировка по цене: $_selectedPriceSort');
      }

      // Восстанавливаем город
      if (savedFilters.containsKey('city_id') && savedFilters['city_id'] is int) {
        _selectedCityId = savedFilters['city_id'] as int;
        if (savedFilters.containsKey('city_name')) {
          _selectedCity = {savedFilters['city_name'] as String};
        }
        print('✅ Восстановлен город: $_selectedCity (ID: $_selectedCityId)');
      }

      // Восстанавливаем атрибуты фильтров
      for (final entry in savedFilters.entries) {
        final key = entry.key;
        final value = entry.value;

        // Пропускаем специальные ключи
        if (key == 'sort_date' ||
            key == 'sort_price' ||
            key == 'city_id' ||
            key == 'city_name') {
          continue;
        }

        // Пытаемся распарсить ключ как ID атрибута
        final attrId = int.tryParse(key);
        if (attrId != null) {
          // 🔍 ВАЖНО: Проверяем и нормализуем структуру данных
          dynamic restoredValue = value;
          
          // Если это Map (диапазон) - убеждаемся что 'min' и 'max' это строки
          if (value is Map) {
            final normalizedMap = <String, dynamic>{};
            value.forEach((k, v) {
              // Преобразуем ключи и значения в нужный формат
              normalizedMap[k.toString()] = v?.toString() ?? '';
            });
            restoredValue = normalizedMap;
            print('✅ Восстановлен ДИАПАЗОН атрибут: $key = min:${normalizedMap['min']}, max:${normalizedMap['max']}');
          } 
          // Если это List (был Set, конвертирован в List при сохранении) - преобразуем обратно в Set
          else if (value is List) {
            restoredValue = (value as List).cast<String>().toSet();
            print('✅ Восстановлен SET (из List) атрибут: $key = ${restoredValue.toString()}');
          }
          // Если это Set (выбранные значения)
          else if (value is Set) {
            restoredValue = value;
            print('✅ Восстановлен SET атрибут: $key = ${value.toList()}');
          }
          // Если это boolean
          else if (value is bool) {
            restoredValue = value;
            print('✅ Восстановлен BOOL атрибут: $key = $value');
          }
          // Обычная строка
          else {
            restoredValue = value;
            print('✅ Восстановлен атрибут: $key = $value (type=${value.runtimeType})');
          }
          
          _selectedValues[attrId] = restoredValue;
          
          // 🔍 Если это диапазон - инициализируем TextEditingControllers сразу
          if (restoredValue is Map) {
            final minKey = attrId * 2;
            final maxKey = attrId * 2 + 1;
            
            final minValue = restoredValue['min']?.toString() ?? '';
            final maxValue = restoredValue['max']?.toString() ?? '';
            
            // Инициализируем контролллеры для диапазонов
            _controllers[minKey] = TextEditingController(text: minValue);
            _controllers[maxKey] = TextEditingController(text: maxValue);
            
            print('   ├─ TextEditingController[$minKey] = "$minValue"');
            print('   └─ TextEditingController[$maxKey] = "$maxValue"');
          }
        }
      }
    });

    print('💾 ═══════════════════════════════════════\n');
  }

  /// Сохраняет текущее состояние фильтров для восстановления при следующих посещениях
  Future<void> _saveFilterState() async {
    final stateToSave = <String, dynamic>{};

    // Сохраняем сортировку
    if (_selectedDateSort != null) {
      stateToSave['sort_date'] = _selectedDateSort;
    }
    if (_selectedPriceSort != null) {
      stateToSave['sort_price'] = _selectedPriceSort;
    }

    // Сохраняем город
    if (_selectedCityId != null) {
      stateToSave['city_id'] = _selectedCityId;
      if (_selectedCity.isNotEmpty) {
        stateToSave['city_name'] = _selectedCity.first;
      }
    }

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

      // ✅ ИСПРАВЛЕНИЕ: Конвертируем Set в List для Hive (Set не поддерживается без адаптера)
      if (value is Set) {
        stateToSave[key.toString()] = value.toList();
      } else {
        stateToSave[key.toString()] = value;
      }
    });

    print('\n💾 ═══════════════════════════════════════');
    print('💾 SAVING FILTER STATE TO HIVE');
    print('💾 Category: ${widget.categoryId}');
    print('💾 Items to save: ${stateToSave.length}');
    stateToSave.forEach((k, v) {
      if (v is Map) {
        print('   ├─ $k: Map ${v.toString()}');
      } else if (v is List) {
        print('   ├─ $k: List ${v.toString()}');
      } else {
        print('   ├─ $k: $v (type=${v.runtimeType})');
      }
    });
    print('💾 ═══════════════════════════════════════\n');

    await HiveService.saveCategoryFilters(widget.categoryId, stateToSave);
  }

  Map<String, dynamic> _collectFilters() {
    final Map<String, dynamic> filters = {};

    print('\n📦 ═══════════════════════════════════════');
    print('📦 _collectFilters() - STARTING');
    print('📦 ═══════════════════════════════════════');

    // DEBUG: Выводим текущее состояние городов
    print('📦 DEBUG STATE:');
    print(
      '   _selectedCityId: $_selectedCityId (type: ${_selectedCityId?.runtimeType})',
    );
    print('   _selectedCity: $_selectedCity');
    print('   _cities.length: ${_cities.length}');

    // Добавить сортировку
    if (_selectedDateSort != null) {
      filters['sort_date'] = _selectedDateSort;
      print('✅ Filter: sort_date = $_selectedDateSort');
    }
    if (_selectedPriceSort != null) {
      filters['sort_price'] = _selectedPriceSort;
      print('✅ Filter: sort_price = $_selectedPriceSort');
    }

    // Добавить выбранный город
    if (_selectedCityId != null) {
      filters['city_id'] = _selectedCityId;
      final cityName = _selectedCity.isNotEmpty
          ? _selectedCity.first
          : 'Unknown';
      // 🟢 ВАЖНО: также добавляем имя города для клиентской фильтрации
      filters['city_name'] = cityName;
      print('✅ Filter: city_id = $_selectedCityId (city: $cityName)');
      print('✅ Filter: city_name = $cityName (для клиентской фильтрации)');
      print('✅ FILTER ADDED TO RESULT!');
    } else {
      print('⚠️  NO city selected. _selectedCityId is null');
      print('   _selectedCity: $_selectedCity');
      print('   _cities available: ${_cities.length}');
      if (_cities.isNotEmpty) {
        print(
          '   Sample cities: ${_cities.take(3).map((c) => c['name']).toList()}',
        );
      }
    }

    // Добавить атрибуты в структуру values {} и value_selected {} (как требует API)
    // ВАЖНО: API разделяет фильтры на:
    // - filters[value_selected][attr_id] = [selected_value_ids] - для выбранных значений (ID < 1000)
    // - filters[values][attr_id] = {min, max} - для диапазонов (ID >= 1000)
    final valueSelectedMap = <String, dynamic>{}; // ID < 1000
    final valuesMap = <String, dynamic>{}; // ID >= 1000

    _selectedValues.forEach((key, value) {
      bool shouldInclude = false;
      dynamic processedValue = value;

      // Определяем тип фильтра по ID атрибута
      final isValueSelectedType = key < 1000;
      final filterType = isValueSelectedType ? 'value_selected' : 'values';

      if (value is Map<String, dynamic>) {
        // Range фильтры: {min: "1", max: "5"} или {min: "", max: ""}
        final min = (value['min'] ?? '').toString().trim();
        final max = (value['max'] ?? '').toString().trim();

        // Включаем только если хотя бы один из min/max заполнен
        if (min.isNotEmpty || max.isNotEmpty) {
          shouldInclude = true;
          // API требует ЧИСЛА для integer/numeric data_type, а не строки!
          // Пытаемся конвертировать в число (int или double)
          final minValue = min.isNotEmpty
              ? (int.tryParse(min) ?? double.tryParse(min) ?? min)
              : '';
          final maxValue = max.isNotEmpty
              ? (int.tryParse(max) ?? double.tryParse(max) ?? max)
              : '';

          processedValue = {
            'min': minValue, // число или пустая строка
            'max': maxValue, // число или пустая строка
          };
          print(
            '✅ Attribute: [$key] = min:$minValue, max:$maxValue (type: $filterType)',
          );
        } else {
          print('⏭️  Skipped: [$key] = {empty range}');
        }
      } else if (value is bool && value == true) {
        // Включаем только true boolean'ы
        shouldInclude = true;
        print('✅ Attribute: [$key] = $value (type: $filterType, bool)');
      } else if (value is bool && value == false) {
        // Исключаем false boolean'ы
        print('⏭️  Skipped: [$key] = false (checkbox not selected)');
      } else if (value != null &&
          value != '' &&
          (value is! Set || value.isNotEmpty)) {
        // Обычные значения (Set, List, String) - это value_selected
        shouldInclude = true;
        if (value is Set && value.isNotEmpty) {
          print(
            '✅ Attribute: [$key] = ${value.join(", ")} (type: Set<String>, count: ${value.length})',
          );
        } else {
          print(
            '✅ Attribute: [$key] = $value (type: $filterType, ${value.runtimeType})',
          );
        }
      }

      if (shouldInclude) {
        if (isValueSelectedType) {
          valueSelectedMap[key.toString()] = processedValue;
        } else {
          valuesMap[key.toString()] = processedValue;
        }
      }
    });

    // Если есть value_selected атрибуты, добавляем их в filters[value_selected]
    if (valueSelectedMap.isNotEmpty) {
      filters['value_selected'] = valueSelectedMap;
      print('✅ value_selected attributes added to filters[value_selected]');
      print('📋 value_selected content:');
      valueSelectedMap.forEach((k, v) {
        print('   [$k] = ${v is Set ? '{Set: ${v.toList()}}' : '{Type: ${v.runtimeType}, Value: $v}'}');
      });
    }

    // Если есть атрибуты диапазонов, добавляем их в filters[values]
    if (valuesMap.isNotEmpty) {
      filters['values'] = valuesMap;
      print('✅ range attributes added to filters[values]');
    }

    print('📦 ═══════════════════════════════════════');
    print('📦 FINAL FILTERS: ${filters.toString()}');
    print('📦 Filter keys: ${filters.keys.toList()}');
    print('📦 Filter is empty? ${filters.isEmpty}');
    print('📦 ═══════════════════════════════════════\n');
    return filters;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: primaryBackground,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.lightBlue),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки фильтров',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _loadFilters,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

              // Блок "Категории"
              _buildCategoriesBlock(),
              const SizedBox(height: 27),

              // Блок "Выберите регион" - скрыт, регионы загружаются автоматически
              // _buildRegionBlock(),
              // const SizedBox(height: 27),

              // Блок "Выберите город"
              _buildCityBlock(),
              const SizedBox(height: 27),

              // Блок "Выберите категорию"
              _buildSelectedCategoryBlock(),
              const SizedBox(height: 27),

              // Блок сортировки
              _buildSortBlock(),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24),
              const SizedBox(height: 5),

              // Динамические фильтры
              _buildDynamicFilters(),

              // const SizedBox(height: 27),
              // const Divider(color: Colors.white24),
              const SizedBox(height: 21),

              // Кнопки управления
              _buildActionButtons(),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
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
            color: Colors.white,
            fontWeight: FontWeight.w500,
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
              _selectedDateSort = null;
              _selectedPriceSort = null;
              _selectedCity.clear();
              _selectedCityId = null;
              _selectedRegion.clear();
              _selectedRegionId = null;
              
              print('🔴 Cleared: date sort, price sort, city, region, all attributes');
            });
            
            // Удалить сохраненные фильтры для этой категории
            await HiveService.deleteCategoryFilters(widget.categoryId);
            print('🔴 Deleted saved filters from Hive for category ${widget.categoryId}');
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

  Widget _buildCategoriesBlock() {
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
        IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: textSecondary,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              widget.categoryName,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildRegionBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Выберите регион",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            if (_regions.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Регионы не загружены')),
                );
              }
              return;
            }

            if (mounted) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return SelectionDialog(
                    title: 'Выберите регион',
                    options: _regions.map((r) => r['name'] as String).toList(),
                    selectedOptions: _selectedRegion,
                    allowMultipleSelection: false,
                    onSelectionChanged: (Set<String> selected) async {
                      if (selected.isNotEmpty) {
                        final selectedRegionName = selected.first;
                        final regionIndex = _regions.indexWhere(
                          (r) => r['name'] == selectedRegionName,
                        );
                        int? regionId;
                        if (regionIndex >= 0) {
                          regionId = _regions[regionIndex]['id'] as int?;
                        }

                        setState(() {
                          _selectedRegion = selected;
                          _selectedRegionId = regionId;
                          _selectedCity.clear();
                          _selectedCityId = null;
                          _cities.clear();
                        });

                        print(
                          '✅ Выбран регион: $selectedRegionName (ID: $regionId)',
                        );

                        // Загрузить города для этого региона
                        if (regionId != null) {
                          await _loadCitiesForRegion(
                            regionId,
                            selectedRegionName,
                          );
                        }
                      }
                      // Проверить mounted перед использованием context
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedRegion.isEmpty
                        ? "Выберите регион"
                        : _selectedRegion.join(', '),
                    style: TextStyle(
                      color: _selectedRegion.isEmpty
                          ? Colors.white70
                          : Colors.white,
                      fontSize: 16,
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

  Widget _buildCityBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle("Выберите город"),
        _buildSelector(
          _selectedCity.isEmpty ? "Выберите город" : _selectedCity.first,
          onTap: () {
            if (_cities.isNotEmpty) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return CitySelectionDialog(
                    title: 'Выберите город',
                    options: _cities.map((c) => c['name'] as String).toList(),
                    selectedOptions: _selectedCity,
                    onSelectionChanged: (Set<String> selected) {
                      if (selected.isNotEmpty) {
                        final selectedCityName = selected.first;
                        final cityIndex = _cities.indexWhere(
                          (c) => c['name'] == selectedCityName,
                        );

                        int? cityId;
                        if (cityIndex >= 0) {
                          cityId = _cities[cityIndex]['id'] as int?;
                        }

                        setState(() {
                          _selectedCity = selected;
                          _selectedCityId = cityId;
                        });

                        print('✅ Выбран город: $selectedCityName (ID: $cityId)');
                      }
                    },
                  );
                },
              );
            } else if (_citiesLoading) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⏳ Города загружаются...')),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '❌ Города не найдены. Проверьте подключение.',
                    ),
                  ),
                );
              }
            }
          },
          showArrow: true,
        ),
      ],
    );
  }

  Widget _buildSelectedCategoryBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Выберите категорию",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: secondaryBackground,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categoryName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Недвижимость / Квартиры",
                          style: TextStyle(
                            color: Color(0xFF7A7A7A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Изменить",
                      style: TextStyle(color: Colors.lightBlue, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildCategoryBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Категория",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: secondaryBackground,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            widget.categoryName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
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

  Widget _sortButton(String label, String key) {
    final bool isActive = (key == "new" || key == "old")
        ? _selectedDateSort == key
        : _selectedPriceSort == key;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (key == "new" || key == "old") {
              // Если уже выбран этот вариант - отменяем, иначе выбираем
              if (_selectedDateSort == key) {
                _selectedDateSort = null;
              } else {
                _selectedDateSort = key;
                // (Сортировка по цене остается независимой)
              }
            } else if (key == "expensive" || key == "cheap") {
              // Если уже выбран этот вариант - отменяем, иначе выбираем
              if (_selectedPriceSort == key) {
                _selectedPriceSort = null;
              } else {
                _selectedPriceSort = key;
                // (Сортировка по дате остается независимой)
              }
            }
          });
        },
        child: Container(
          height: 35,
          decoration: BoxDecoration(
            color: isActive ? activeIconColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? Colors.transparent : Colors.white70,
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

  Widget _buildDynamicFilters() {
    if (_attributes.isEmpty) {
      print(
        '⚠️ _buildDynamicFilters: No attributes loaded! _attributes.length = 0',
      );
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Фильтры не загружены',
            style: TextStyle(color: Colors.red, fontSize: 14),
          ),
        ),
      );
    }

    print('✅ _buildDynamicFilters: Building ${_attributes.length} filters');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const SizedBox(height: 16),
        ..._attributes.map((attr) {
          print(
            '📋 FIELD: ID=${attr.id.toString().padLeft(4)} | Title: ${attr.title} | Style: ${attr.style}${attr.styleSingle != null ? ', styleSingle: ${attr.styleSingle}' : ''}',
          );

          // Пропустить скрытые поля
          if (attr.isHidden) {
            return const SizedBox.shrink();
          }

          // Пропустить поле "Вам предложат цену"
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

  Widget _buildFilterField(Attribute attr) {
    // Логика определения типа фильтра на основе флагов и документации
    // Приоритет: styleSingle точное совпадение > isSpecialDesign > (isTitleHidden && isMultiple) > isRange > empty > isPopup > isMultiple > else
    print(
      '    🎨 _buildFilterField: ID=${attr.id}, Title="${attr.title}", '
      'values.count=${attr.values.length}, isRange=${attr.isRange}, '
      'isMultiple=${attr.isMultiple}, isSpecialDesign=${attr.isSpecialDesign}, '
      'isTitleHidden=${attr.isTitleHidden}, isPopup=${attr.isPopup}, '
      'styleSingle="${attr.styleSingle ?? ""}"',
    );

    // Style F: Popup диалог с квадратными чекбоксами - определяется по styleSingle="F"
    // Это наивысший приоритет, так как API явно указывает этот стиль
    if (attr.styleSingle == "F" && attr.values.isNotEmpty) {
      print(
        '    -> Rendering as POPUP SELECT CHECKBOXES (Style F) - styleSingle="F"',
      );
      return _buildStyleFPopupFilter(attr);
    }

    // Style B1: Одиночный чекбокс - определяется по styleSingle="B1"
    // Высокий приоритет, так как API явно указывает этот стиль
    if (attr.styleSingle == "B1") {
      print(
        '    -> Rendering as SINGLE CHECKBOX (Style B1) - styleSingle="B1"',
      );
      return _buildB1Field(attr);
    }

    // Style I: Список чекбоксов - определяется по styleSingle="I"
    // Высокий приоритет, так как API явно указывает этот стиль
    if (attr.styleSingle == "I") {
      print(
        '    -> Rendering as MULTIPLE CHECKBOXES (Style I) - styleSingle="I"',
      );
      return _buildStyleIField(attr);
    }

    // Style J1: Календарь с выбором даты и времени - определяется по styleSingle="J1"
    // Высокий приоритет, так как API явно указывает этот стиль
    if (attr.styleSingle == "J1") {
      print(
        '    -> Rendering as CALENDAR DATE/TIME (Style J1) - styleSingle="J1"',
      );
      return _buildStyleJ1Field(attr);
    }

    // Style K1/K: Календарь с выбором даты и времени (K-Calendar) - определяется по styleSingle="K1" или "K"
    // Высокий приоритет, так как API явно указывает этот стиль
    if (attr.styleSingle == "K1" || attr.styleSingle == "K") {
      print(
        '    -> Rendering as K-CALENDAR DATE/TIME (Style K1) - styleSingle="${attr.styleSingle}"',
      );
      return _buildStyleK1Field(attr);
    }

    // Style C: Да/Нет кнопки (Ипотека, Вид сделки)
    // Флаг isSpecialDesign=true указывает на кнопки для выбора уникального значения
    if (attr.isSpecialDesign) {
      print(
        '    -> Rendering as YES/NO BUTTONS (Style C) - isSpecialDesign=true',
      );
      return _buildSpecialDesignFilter(attr);
    }

    // Style I: Чекбоксы без popup (Возможность торга, Без комиссии)
    // Комбинация: isTitleHidden=true && isMultiple=true && values не пусты
    if (attr.isTitleHidden && attr.isMultiple && attr.values.isNotEmpty) {
      print(
        '    -> Rendering as CHECKBOXES (Style I) - isTitleHidden && isMultiple',
      );
      return _buildCheckboxFilter(attr);
    }

    // Диапазоны от/до (Style A, E, G)
    // Флаг isRange=true указывает на поле с минимум и максимум значениями
    if (attr.isRange) {
      print('    -> Rendering as RANGE (Style A/E/G) - isRange=true');
      return _buildRangeFilterField(attr);
    }

    // Текстовое поле (Style H)
    // Если нет вариантов для выбора - это текстовое поле
    if (attr.values.isEmpty) {
      print('    -> Rendering as TEXT INPUT (Style H) - no values');
      return _buildTextFilterField(attr);
    }

    // Style F: Popup диалог с чекбоксами для множественного выбора (fallback)
    // isPopup=true указывает на popup диалог с чекбоксами со множественным выбором
    if (attr.isPopup && attr.values.isNotEmpty) {
      print(
        '    -> Rendering as POPUP SELECT CHECKBOXES (Style F) - isPopup=true',
      );
      return _buildStyleFPopupFilter(attr);
    }

    // Style D: Multiple select с popup (Тип дома)
    // isMultiple=true && values не пусты = множественный выбор через popup
    if (attr.isMultiple) {
      print(
        '    -> Rendering as MULTIPLE SELECT POPUP (Style D) - isMultiple=true',
      );
      return _buildStyleDMultipleFilter(attr);
    }

    // Single select dropdown (неиспользуемый в текущей документации)
    // Остальные случаи с values = одиночный выбор через dropdown
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
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          _buildTitle(attr.title + (attr.isRequired ? '*' : '')),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        // Всегда в одну строку с Expanded для каждой кнопки
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
        _buildStyleHeader(attr),
        // Если название не скрыто, показываем его
        if (!attr.isTitleHidden)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(attr.title + (attr.isRequired ? '*' : '')),
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

  Widget _buildTextFilterField(Attribute attr) {
    final controller = _controllers.putIfAbsent(
      attr.id,
      () => TextEditingController(text: _selectedValues[attr.id] ?? ''),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          _buildTitle(attr.title + (attr.isRequired ? '*' : '')),
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

  Widget _buildRangeFilterField(Attribute attr) {
    _selectedValues[attr.id] ??= {'min': '', 'max': ''};
    Map<String, dynamic> range = _selectedValues[attr.id] is Map
        ? _selectedValues[attr.id] as Map<String, dynamic>
        : {'min': '', 'max': ''};

    final minKey = attr.id * 2;
    final maxKey = attr.id * 2 + 1;

    // 🔍 ДИАГНОСТИКА: Логируем состояние при построении
    print('\n🎨 Building RANGE field:');
    print('   Attribute ID: ${attr.id}, Title: "${attr.title}"');
    print('   Range value: $range (type=${range.runtimeType})');
    print('   Is controller for min (key=$minKey) already exists? ${_controllers.containsKey(minKey)}');
    print('   Is controller for max (key=$maxKey) already exists? ${_controllers.containsKey(maxKey)}');

    // Если контроллеры уже существуют, обновляем их текст из текущих значений
    if (_controllers.containsKey(minKey)) {
      _controllers[minKey]!.text = (range['min'] ?? '').toString();
      print('   ✅ Updated existing minController: "${_controllers[minKey]!.text}"');
    }
    if (_controllers.containsKey(maxKey)) {
      _controllers[maxKey]!.text = (range['max'] ?? '').toString();
      print('   ✅ Updated existing maxController: "${_controllers[maxKey]!.text}"');
    }

    final minController = _controllers.putIfAbsent(
      minKey,
      () {
        final controller = TextEditingController(text: (range['min'] ?? '').toString());
        print('   ✅ Created NEW minController with text: "${controller.text}"');
        return controller;
      },
    );

    final maxController = _controllers.putIfAbsent(
      maxKey,
      () {
        final controller = TextEditingController(text: (range['max'] ?? '').toString());
        print('   ✅ Created NEW maxController with text: "${controller.text}"');
        return controller;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          _buildTitle(attr.title + (attr.isRequired ? '*' : '')),
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
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          _buildTitle(attr.title + (attr.isRequired ? '*' : '')),
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
                  // Не вызываем Navigator.pop() здесь - диалог это сделает сам
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

  /// Style F: Popup диалог со квадратными чекбоксами для множественного выбора (Тип сделки)
  /// Выводит кнопку с выпадающим меню, где можно выбрать НЕСКОЛЬКИХ вариантов
  /// isPopup=true указывает на этот стиль
  Widget _buildStyleFPopupFilter(Attribute attr) {
    _selectedValues[attr.id] ??= <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    // Преобразуем сохраненные IDы в текстовые значения для отображения
    List<String> displayValues = <String>[];
    if (selected.isNotEmpty) {
      for (var attrValue in attr.values) {
        if (selected.contains(attrValue.id.toString())) {
          displayValues.add(attrValue.value);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          _buildTitle(attr.title + (attr.isRequired ? '*' : '')),
        if (!attr.isTitleHidden) const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            _showStyleFMultiSelectDialog(attr, selected);
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
                    selected.isEmpty ? 'Выбрать' : displayValues.join(', '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected.isEmpty ? Colors.white70 : Colors.white,
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

  /// Style D: Popup с множественным выбором через SelectionDialog (Тип дома)
  /// Выводит кнопку с выпадающим меню SelectionDialog для выбора НЕСКОЛЬКИХ вариантов
  /// isMultiple=true указывает на этот стиль
  Widget _buildStyleDMultipleFilter(Attribute attr) {
    _selectedValues[attr.id] ??= <String>{};
    Set<String> storedIds = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    // 🔴 FIX #1: Преобразуем сохраненные IDы в текстовые значения для отображения в диалоге
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
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          _buildTitle(attr.title + (attr.isRequired ? '*' : '')),
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
                selectedOptions: displaySelected,  // ✅ FIX #1: Передаем текстовые значения, не IDы
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
                  // Не вызываем Navigator.pop() здесь - диалог это сделает сам
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

  /// Показывает диалог со квадратными чекбоксами для множественного выбора (Style F)
  /// Стиль полностью совпадает с SelectionDialog (Style D1) для единообразия
  void _showStyleFMultiSelectDialog(
    Attribute attr,
    Set<String> currentSelected,
  ) {
    print(
      '🎨 StyleF Dialog opened: ID=${attr.id}, Title="${attr.title}", Current: $currentSelected',
    );

    Set<String> tempSelected = Set.from(currentSelected);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF222E3A),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 10, 13, 20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Кнопка закрытия X
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        print('❌ StyleF Dialog cancelled');
                        Navigator.of(context).pop();
                      },
                    ),
                    // Заголовок
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            attr.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 23),
                    // Список с чекбоксами
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: attr.values.asMap().entries.map((entry) {
                            final value = entry.value;
                            final valueId = value.id.toString();
                            final isChecked = tempSelected.contains(valueId);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        if (isChecked) {
                                          print(
                                            '❌ StyleF Unchecked: ID=$valueId, Value="${value.value}"',
                                          );
                                          tempSelected.remove(valueId);
                                        } else {
                                          print(
                                            '✅ StyleF Checked: ID=$valueId, Value="${value.value}"',
                                          );
                                          tempSelected.add(valueId);
                                        }
                                      });
                                    },
                                    child: Text(
                                      value.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  CustomCheckbox(
                                    value: isChecked,
                                    onChanged: (bool val) {
                                      setDialogState(() {
                                        if (val) {
                                          print(
                                            '✅ StyleF Checkbox Checked: ID=$valueId, Value="${value.value}"',
                                          );
                                          tempSelected.add(valueId);
                                        } else {
                                          print(
                                            '❌ StyleF Checkbox Unchecked: ID=$valueId, Value="${value.value}"',
                                          );
                                          tempSelected.remove(valueId);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Кнопки
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(127, 35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            print('❌ StyleF Dialog cancelled');
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: Color(0xFF0EA5E9)),
                            minimumSize: const Size(127, 35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            print(
                              '✅ StyleF Dialog confirmed: Final selected=$tempSelected',
                            );
                            setState(() {
                              _selectedValues[attr.id] = tempSelected;
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Готово',
                            style: TextStyle(
                              color: Color(0xFF0EA5E9),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Style B1: Одиночный чекбокс без контейнера (Возможен торг)
  /// Выводит просто текст с квадратным чекбоксом справа, без фонового контейнера
  /// Используется для одиночного чекбокса в списке фильтров
  Widget _buildStyleB1Filter(Attribute attr) {
    _selectedValues[attr.id] ??= false;
    bool isChecked =
        _selectedValues[attr.id] == true ||
        _selectedValues[attr.id] == attr.values[0].value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        GestureDetector(
          onTap: () {
            setState(() {
              // Переключаем между false и значением
              _selectedValues[attr.id] = isChecked
                  ? false
                  : attr.values[0].value;
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

  /// Style B1: Одиночный чекбокс с просмотром фильтров (Возможен торг)
  /// Выводит чекбокс с надписью слева и квадратным чекбоксом справа
  Widget _buildB1Field(Attribute attr) {
    _selectedValues[attr.id] ??= false;
    bool isChecked = _selectedValues[attr.id] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedValues[attr.id] = !isChecked;
            });
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  attr.title,
                  style: const TextStyle(color: textPrimary, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              CustomCheckbox(
                value: isChecked,
                onChanged: (v) {
                  setState(() {
                    _selectedValues[attr.id] = v;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Style I: Список чекбоксов для множественного выбора (Раздельный выбор)
  /// Выводит название поля и список чекбоксов в вертикальном порядке
  Widget _buildStyleIField(Attribute attr) {
    _selectedValues[attr.id] ??= <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        // Название поля
        if (attr.title.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attr.title + (attr.isRequired ? '*' : ''),
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        // Список чекбоксов
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
                      Expanded(
                        child: Text(
                          value.value,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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

  /// Style J1: Календарь с выбором даты и времени (Аренда)
  /// Использует RentTimeWidget для отображения диапазона дат и времени
  Widget _buildStyleJ1Field(Attribute attr) {
    // Initialize storage for date/time values with proper type safety
    // Use a local variable to ensure consistency within this build method
    final attrId = attr.id;
    
    // Гарантируем, что значение инициализировано как Map
    if (_selectedValues[attrId] is! Map) {
      _selectedValues[attrId] = {
        'dateFrom': null,
        'timeFrom': null,
        'dateTo': null,
        'timeTo': null,
      };
    }

    // Получаем ссылку на Map и гарантируем его наличие
    Map<String, dynamic> timeData = _selectedValues[attrId] as Map<String, dynamic>;
    
    // Убеждаемся, что все ключи существуют
    timeData.putIfAbsent('dateFrom', () => null);
    timeData.putIfAbsent('timeFrom', () => null);
    timeData.putIfAbsent('dateTo', () => null);
    timeData.putIfAbsent('timeTo', () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        // Название поля
        if (!attr.isTitleHidden)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attr.title + (attr.isRequired ? '*' : ''),
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 9),
            ],
          ),
        // Виджет выбора даты/времени
        RentTimeWidget(
          dateFrom: timeData['dateFrom'] as String?,
          timeFrom: timeData['timeFrom'] as String?,
          dateTo: timeData['dateTo'] as String?,
          timeTo: timeData['timeTo'] as String?,
          onDateFromSelected: (date) {
            setState(() {
              // Создаём новый Map вместо изменения существующего
              // Это гарантирует правильную типизацию
              if (_selectedValues.containsKey(attrId)) {
                final existing = _selectedValues[attrId];
                if (existing is Map) {
                  _selectedValues[attrId] = {
                    'dateFrom': date,
                    'timeFrom': existing['timeFrom'] ?? null,
                    'dateTo': existing['dateTo'] ?? null,
                    'timeTo': existing['timeTo'] ?? null,
                  };
                } else {
                  _selectedValues[attrId] = {
                    'dateFrom': date,
                    'timeFrom': null,
                    'dateTo': null,
                    'timeTo': null,
                  };
                }
              }
            });
          },
          onDateToSelected: (date) {
            setState(() {
              // Создаём новый Map вместо изменения существующего
              // Это гарантирует правильную типизацию
              if (_selectedValues.containsKey(attrId)) {
                final existing = _selectedValues[attrId];
                if (existing is Map) {
                  _selectedValues[attrId] = {
                    'dateFrom': existing['dateFrom'] ?? null,
                    'timeFrom': existing['timeFrom'] ?? null,
                    'dateTo': date,
                    'timeTo': existing['timeTo'] ?? null,
                  };
                } else {
                  _selectedValues[attrId] = {
                    'dateFrom': null,
                    'timeFrom': null,
                    'dateTo': date,
                    'timeTo': null,
                  };
                }
              }
            });
          },
        ),
      ],
    );
  }

  /// Style K1/K: K-Camera с выбором даты и времени (Аренда - Style K)
  /// Использует KRentTimeWidget для отображения диапазона дат и времени компактной формой
  Widget _buildStyleK1Field(Attribute attr) {
    // Initialize storage for date/time values with proper type safety
    // Use a local variable to ensure consistency within this build method
    final attrId = attr.id;
    
    // Гарантируем, что значение инициализировано как Map
    if (_selectedValues[attrId] is! Map) {
      _selectedValues[attrId] = {
        'dateFrom': null,
        'timeFrom': null,
        'dateTo': null,
        'timeTo': null,
      };
    }

    // Получаем ссылку на Map и гарантируем его наличие
    Map<String, dynamic> timeData = _selectedValues[attrId] as Map<String, dynamic>;
    
    // Убеждаемся, что все ключи существуют
    timeData.putIfAbsent('dateFrom', () => null);
    timeData.putIfAbsent('timeFrom', () => null);
    timeData.putIfAbsent('dateTo', () => null);
    timeData.putIfAbsent('timeTo', () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        // Название поля
        if (!attr.isTitleHidden)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attr.title + (attr.isRequired ? '*' : ''),
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 9),
            ],
          ),
        // K-Calendar виджет выбора даты/времени
        KRentTimeWidget(
          dateFrom: timeData['dateFrom'] as String?,
          timeFrom: timeData['timeFrom'] as String?,
          dateTo: timeData['dateTo'] as String?,
          timeTo: timeData['timeTo'] as String?,
          onDateFromSelected: (date) {
            setState(() {
              // Создаём новый Map вместо изменения существующего
              // Это гарантирует правильную типизацию
              if (_selectedValues.containsKey(attrId)) {
                final existing = _selectedValues[attrId];
                if (existing is Map) {
                  _selectedValues[attrId] = {
                    'dateFrom': date,
                    'timeFrom': existing['timeFrom'] ?? null,
                    'dateTo': existing['dateTo'] ?? null,
                    'timeTo': existing['timeTo'] ?? null,
                  };
                } else {
                  _selectedValues[attrId] = {
                    'dateFrom': date,
                    'timeFrom': null,
                    'dateTo': null,
                    'timeTo': null,
                  };
                }
              }
            });
          },
          onDateToSelected: (date) {
            setState(() {
              // Создаём новый Map вместо изменения существующего
              // Это гарантирует правильную типизацию
              if (_selectedValues.containsKey(attrId)) {
                final existing = _selectedValues[attrId];
                if (existing is Map) {
                  _selectedValues[attrId] = {
                    'dateFrom': existing['dateFrom'] ?? null,
                    'timeFrom': existing['timeFrom'] ?? null,
                    'dateTo': date,
                    'timeTo': existing['timeTo'] ?? null,
                  };
                } else {
                  _selectedValues[attrId] = {
                    'dateFrom': null,
                    'timeFrom': null,
                    'dateTo': date,
                    'timeTo': null,
                  };
                }
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
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
              print('\n🔵 ════════════════════════════════════════');
              print('🔵 BUTTON "Применить фильтры" PRESSED');
              print('🔵 ════════════════════════════════════════');

              final filters = _collectFilters();

              print('🔵 About to return filters to listings_screen');
              print('🔵 Filters to return: $filters');
              print('🔵 ════════════════════════════════════════\n');

              // 💾 ВАЖНО: Сохраняем СОСТОЯНИЕ фильтров (из _selectedValues), а не преобразованные фильтры
              // Это позволяет правильно восстановить все значения при следующем открытии экрана
              await _saveFilterState();

              if (mounted) {
                Navigator.pop(context, filters);
              }
            },
            child: const Text(
              "Применить фильтры",
              style: TextStyle(color: Colors.white),
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
            onPressed: () => Navigator.pop(context),
            child: const Text("Отмена", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
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

  /// Builds style header that displays attribute style information
  /// Shows the attribute style code above the field label
  /// Used for debugging and validating correct filter rendering
  Widget _buildStyleHeader(Attribute attr) {
    // Use styleSingle from API (e.g., E1, H, D1)
    // This is the actual submission style code returned by API
    final displayStyle = attr.styleSingle ?? '';
    if (displayStyle.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Показывает стили над полями для отладки и валидации
        Text(
          'Style2: $displayStyle',
          style: const TextStyle(
            color: Color(0xFFFF1744), // Red color for debug visibility
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Загружает регионы из API при инициализации экрана
  Future<void> _loadRegions() async {
    try {
      print('📍 Загрузка регионов...');
      final token = TokenService.currentToken;

      if (token == null) {
        print('ℹ️ _loadRegions: Токен не найден, загружаем без токена');
      }

      final regions = await ApiService.getRegions(token: token);

      if (mounted) {
        setState(() {
          _regions = regions;
        });
      }
      print('✅ Загружено ${regions.length} регионов');

      // Автоматически загрузить города из всех регионов
      if (regions.isNotEmpty) {
        await _loadAllCitiesFromAllRegions(regions);
      }
    } catch (e) {
      print('❌ Ошибка загрузки регионов: $e');
      // Попытаюсь загрузить снова через 3 секунды
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadRegions();
      });
    }
  }

  /// Загружает города из всех доступных регионов и объединяет их в один список
  Future<void> _loadAllCitiesFromAllRegions(
    List<Map<String, dynamic>> regions,
  ) async {
    try {
      if (mounted) {
        setState(() {
          _citiesLoading = true;
        });
      }

      print('\n🔍 ═══════════════════════════════════════');
      print('🔍 _loadAllCitiesFromAllRegions() - STARTING');
      print('🔍 Regions count: ${regions.length}');
      print('🔍 ═══════════════════════════════════════');

      final token = TokenService.currentToken;

      final Map<int, Map<String, dynamic>> citiesMap = {};

      // Загрузить города для каждого региона
      for (final region in regions) {
        final regionId = region['id'] as int?;
        final regionName = region['name'] as String?;

        if (regionId == null || regionName == null) {
          print('⚠️  Skipping region with null ID or name: $region');
          continue;
        }

        try {
          // Подготовить поисковый запрос
          String searchQuery = regionName;
          if (searchQuery.length < 3) {
            searchQuery = searchQuery + '   ';
          }

          print('📍 Loading cities for region: "$regionName" (ID=$regionId)');

          // Загрузить города через API
          final response = await AddressService.searchAddresses(
            query: searchQuery,
            token: token,
            types: ['city'],
          );

          print('   ✅ API returned ${response.data.length} results');

          // Добавить города в карту (без дубликатов по ID)
          for (final result in response.data) {
            final cityId = result.city?.id;
            final cityName = result.city?.name;

            if (cityId != null) {
              if (!citiesMap.containsKey(cityId)) {
                citiesMap[cityId] = {
                  'name': cityName ?? '',
                  'id': cityId,
                  'main_region_id': result.main_region?.id,
                };
                print('      + City added: "$cityName" (ID=$cityId)');
              }
            } else {
              print('      ⚠️  City with null ID skipped: $cityName');
            }
          }

          print(
            '   📊 Cities map now has ${citiesMap.length} total unique cities',
          );
        } catch (e) {
          print('   ❌ Ошибка загрузки городов для "$regionName": $e');
        }
      }

      // Обновить состояние с объединённым списком городов
      if (mounted) {
        setState(() {
          _cities = citiesMap.values.toList();
          _citiesLoading = false;
        });

        print('\n🔍 ═══════════════════════════════════════');
        print('🔍 _loadAllCitiesFromAllRegions() - COMPLETE');
        if (citiesMap.isNotEmpty) {
          print('✅ Всего загружено ${_cities.length} уникальных городов');
          print('🔍 First 3 cities:');
          for (int i = 0; i < (_cities.length > 3 ? 3 : _cities.length); i++) {
            print('   [${_cities[i]['id']}] - ${_cities[i]['name']}');
          }
        } else {
          print('⚠️  На городов не найдено');
        }
        print('🔍 ═══════════════════════════════════════\n');
      }
    } catch (e) {
      print('❌ Ошибка при загрузке городов из регионов: $e');
      print('   Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _citiesLoading = false;
        });
      }
    }
  }

  /// Загружает города для выбранного региона через API
  Future<void> _loadCitiesForRegion(int regionId, String regionName) async {
    try {
      print('🔍 Загрузка городов для области: "$regionName" (ID: $regionId)');
      final token = TokenService.currentToken;

      // Подготовить поисковый запрос
      String searchQuery = regionName;
      if (searchQuery.length < 3) {
        searchQuery =
            searchQuery + '   '; // Паддированием до минимум 3 символов
      }

      // Загрузить города через API
      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['city'],
      );

      print('✅ API вернул ${response.data.length} результатов');

      if (mounted) {
        setState(() {
          _cities = response.data
              .where((result) => result.main_region?.id == regionId)
              .map(
                (result) => {
                  'name': result.city?.name ?? '',
                  'id': result.city?.id,
                  'main_region_id': result.main_region?.id,
                },
              )
              .toList();
        });
        print(
          '✅ Загружено ${_cities.length} городов для области "$regionName"',
        );
      }
    } catch (e) {
      print('❌ Ошибка загрузки городов: $e');
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки городов: $e')),
          );
        } catch (ex) {
          print('⚠️ Cannot show snackbar: $ex');
        }
      }
    }
  }
}
