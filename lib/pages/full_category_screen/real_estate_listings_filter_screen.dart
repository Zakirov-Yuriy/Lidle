import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/services/attribute_resolver.dart';

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
  int? _selectedRegionId;
  int? _selectedCityId;
  bool _citiesLoading = false; // Индикатор загрузки городов

  // =============== Sort Options ===============
  String? _selectedDateSort;
  String? _selectedPriceSort;

  late AttributeResolver _attributeResolver;

  @override
  void initState() {
    super.initState();
    _attributeResolver = AttributeResolver([]);
    _loadFilters();
    _loadRegions();
    // Загрузить применённые фильтры если они есть
    if (widget.appliedFilters != null) {
      _loadAppliedFilters();
    }
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
      final token = HiveService.getUserData('token') as String?;

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
          _attributeResolver = AttributeResolver(attributes);
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
          (value is! Set || (value as Set).isNotEmpty)) {
        // Обычные значения (Set, List, String) - это value_selected
        shouldInclude = true;
        if (value is Set && (value as Set).isNotEmpty) {
          print(
            '✅ Attribute: [$key] = ${(value as Set).join(", ")} (type: Set<String>, count: ${(value as Set).length})',
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
          onTap: () {
            setState(() {
              _selectedValues.clear();
              _selectedDateSort = null;
              _selectedPriceSort = null;
            });
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
        const Text(
          "Выберите город",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            print('\n🏙️ ════════════════════════════════════════');
            print('🏙️ City block tapped');
            print('🏙️ Cities available: ${_cities.length}');
            print('🏙️ Is loading: $_citiesLoading');

            if (_cities.isNotEmpty) {
              print(
                '🏙️ Opening CitySelectionDialog with ${_cities.length} cities',
              );
              print(
                '🏙️ First city: ${_cities[0]['name']} (ID: ${_cities[0]['id']})',
              );
            }
            print('🏙️ ════════════════════════════════════════\n');

            // Показать диалог выбора города
            if (_cities.isNotEmpty) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return CitySelectionDialog(
                    title: 'Выберите город',
                    options: _cities.map((c) => c['name'] as String).toList(),
                    selectedOptions: _selectedCity,
                    onSelectionChanged: (Set<String> selected) {
                      print('\n🟢 ════════════════════════════════════════');
                      print('🟢 onSelectionChanged CALLED');
                      print('🟢 Selected options: $selected');

                      if (selected.isNotEmpty) {
                        final selectedCityName = selected.first;
                        print('🟢 Looking for city: "$selectedCityName"');
                        print('🟢 Total cities in _cities: ${_cities.length}');

                        // Вывести все города для отладки
                        for (int i = 0; i < _cities.length; i++) {
                          print(
                            '   - [${_cities[i]['id']}] "${_cities[i]['name']}"',
                          );
                          if (_cities[i]['name'] == selectedCityName) {
                            print('      ✅ FOUND MATCH at index $i');
                          }
                        }

                        final cityIndex = _cities.indexWhere(
                          (c) => c['name'] == selectedCityName,
                        );
                        print('🟢 City index: $cityIndex');

                        int? cityId;
                        if (cityIndex >= 0) {
                          cityId = _cities[cityIndex]['id'] as int?;
                          print('🟢 City ID found: $cityId');
                        } else {
                          print('🟢 ⚠️  CITY NOT FOUND in _cities!');
                        }

                        setState(() {
                          _selectedCity = selected;
                          _selectedCityId = cityId;
                          print(
                            '🟢 SET STATE: _selectedCityId = $_selectedCityId',
                          );
                          print('🟢 SET STATE: _selectedCity = $_selectedCity');
                        });

                        print(
                          '✅ Выбран город: $selectedCityName (ID: $cityId)',
                        );
                      } else {
                        print('🟢 ⚠️  selected is empty!');
                      }
                      print('🟢 ════════════════════════════════════════\n');
                      // Не вызываем Navigator.pop() здесь - диалог это сделает сам
                    },
                  );
                },
              );
            } else if (_citiesLoading) {
              if (mounted) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⏳ Города загружаются...')),
                  );
                } catch (e) {
                  print('⚠️ Cannot show snackbar: $e');
                }
              }
            } else {
              if (mounted) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '❌ Города не найдены. Проверьте подключение.',
                      ),
                    ),
                  );
                } catch (e) {
                  print('⚠️ Cannot show snackbar: $e');
                }
              }
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
                    _selectedCity.isEmpty
                        ? "Выберите город"
                        : _selectedCity.join(', '),
                    style: TextStyle(
                      color: _selectedCity.isEmpty
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
          // Пропустить скрытые поля
          if (attr.isHidden) {
            print(
              '  - Skipping hidden field: ID=${attr.id}, Title="${attr.title}"',
            );
            return const SizedBox.shrink();
          }

          // Пропустить поле "Вам предложат цену"
          if (attr.title.contains('Вам предложат цену')) {
            print('  - Skipping field: ID=${attr.id}, Title="${attr.title}"');
            return const SizedBox.shrink();
          }

          print(
            '  - Rendering field: ID=${attr.id}, Title="${attr.title}", Style="${attr.style}"',
          );

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

    // Style B1: Одиночный чекбокс (Возможен торг)
    // Если есть ровно одно значение и это не специальный дизайн/range/popup
    if (attr.values.length == 1 &&
        !attr.isRange &&
        !attr.isSpecialDesign &&
        !attr.isPopup) {
      print('    -> Rendering as SINGLE CHECKBOX (Style B1) - one value only');
      return _buildStyleB1Filter(attr);
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

    final buttonCount = attr.values.length;

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
            final isSelected = selected == value.value;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < attr.values.length - 1 ? 8.0 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedValues[attr.id] = isSelected ? '' : value.value;
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
                selectedOptions: selected.isEmpty ? {} : {selected},
                onSelectionChanged: (selected) {
                  setState(() {
                    _selectedValues[attr.id] = selected.isEmpty
                        ? ''
                        : selected.first;
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
                    selected.isEmpty ? 'Выбрать' : selected,
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

  /// Style F: Popup диалог со квадратными чекбоксами для множественного выбора (Тип сделки)
  /// Выводит кнопку с выпадающим меню, где можно выбрать НЕСКОЛЬКИХ вариантов
  /// isPopup=true указывает на этот стиль
  Widget _buildStyleFPopupFilter(Attribute attr) {
    _selectedValues[attr.id] ??= <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

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
                    selected.isEmpty ? 'Выбрать' : '${selected.length} выбрано',
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
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    print(
      '🎨 StyleD Filter Built: ID=${attr.id}, Title="${attr.title}", Current selected: $selected',
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
              '🎯 StyleD Dialog opened: ID=${attr.id}, Title="${attr.title}"',
            );
            showDialog(
              context: context,
              builder: (_) => SelectionDialog(
                title: attr.title,
                options: attr.values.map((v) => v.value).toList(),
                selectedOptions: selected,
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
                    selected.isEmpty ? 'Выбрать' : '${selected.length} выбрано',
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
                constraints: const BoxConstraints(maxHeight: 359.0),
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
            onPressed: () {
              print('\n🔵 ════════════════════════════════════════');
              print('🔵 BUTTON "Применить фильтры" PRESSED');
              print('🔵 ════════════════════════════════════════');

              final filters = _collectFilters();

              print('🔵 About to return filters to listings_screen');
              print('🔵 Filters to return: $filters');
              print('🔵 ════════════════════════════════════════\n');

              Navigator.pop(context, filters);
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

  /// Builds style header that displays attribute style information
  /// Shows the attribute style code above the field label
  /// Used for debugging and validating correct filter rendering
  Widget _buildStyleHeader(Attribute attr) {
    // Use styleSingle from API (e.g., E1, H, D1)
    // This is the actual submission style code returned by API
    final displayStyle = attr.styleSingle ?? '';
    final stylePrefix = 'Style';

    if (displayStyle.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Показывает стили над полями для отладки и валидации
        // Text(
        //   '$stylePrefix: $displayStyle',
        //   style: const TextStyle(
        //     color: Color(0xFFFF1744), // Red color for debug visibility
        //     fontSize: 12,
        //     fontWeight: FontWeight.w600,
        //     letterSpacing: 0.3,
        //   ),
        // ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Загружает регионы из API при инициализации экрана
  Future<void> _loadRegions() async {
    try {
      print('📍 Загрузка регионов...');
      final token = await HiveService.getUserData('token');

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

      final token = await HiveService.getUserData('token');

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
      final token = await HiveService.getUserData('token');

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
