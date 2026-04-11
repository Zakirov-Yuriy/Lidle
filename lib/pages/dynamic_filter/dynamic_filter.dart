import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/j_calendar/j_calendar_widget.dart';
import 'package:lidle/widgets/components/k_calendar/k_calendar_widget.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/street_selection_dialog.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import '../../../constants.dart';
import '../../../services/api_service.dart';
import '../../../services/address_service.dart';
import '../../../services/user_service.dart';
import '../../../services/attribute_resolver.dart';
import '../../../models/filter_models.dart';
import '../../../models/create_advert_model.dart';
import '../../../services/token_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';
import 'package:lidle/pages/add_listing/real_estate_subcategories_screen.dart';
import 'package:lidle/pages/add_listing/publication_tariff_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_screen.dart';
import 'package:lidle/core/logger.dart';

// ============================================================
// "Виджет: Экран добавления аренды квартиры в недвижимость"
// ============================================================
class DynamicFilter extends StatefulWidget {
  static const String routeName = '/add-real-estate-apt';

  final int? categoryId;
  final int?
  advertId; // ID объявления для редактирования (если null - создание нового)

  const DynamicFilter({super.key, this.categoryId, this.advertId});

  @override
  State<DynamicFilter> createState() => _DynamicFilterState();
}

// ============================================================
// "Класс состояния: Управление состоянием экрана аренды квартиры"
// ============================================================
class _DynamicFilterState extends State<DynamicFilter> {
  // =============== UI Mode ===============
  static const bool _isSubmissionMode =
      true; // DynamicFilter is for creating/submitting ads

  // =============== Edit Mode ===============
  bool _isEditMode = false; // Режим редактирования
  // ignore: unused_field
  Map<String, dynamic>? _editAdvertData; // Данные объявления для редактирования
  // ignore: unused_field
  bool _isLoadingEditData = false; // Загрузка данных объявления
  int? _editAdvertCategoryId; // Категория объявления при редактировании

  // =============== Main state ===============
  List<Attribute> _attributes = [];
  Map<int, dynamic> _selectedValues = {};
  bool _isLoading = true;
  bool _isPublishing = false;
  String _publishingProgress = '';
  Map<int, TextEditingController> _controllers = {};

  // Category name and attribute resolver
  String _categoryName = '';
  late AttributeResolver _attributeResolver = AttributeResolver(
    [],
  ); // Инициализируется when filters loaded

  // User contacts
  List<Map<String, dynamic>> _userPhones = [];
  List<Map<String, dynamic>> _userEmails = [];
  List<Map<String, dynamic>> _userTelegrams = [];
  List<Map<String, dynamic>> _userWhatsapps = [];

  // Text Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phone1Controller = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _telegramController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();

  // Scroll controller for error handling
  final ScrollController _scrollController = ScrollController();

  // Address data from API
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _streets = [];
  List<Map<String, dynamic>> _buildings = [];

  // Selected address values
  Set<String> _selectedRegion = {};
  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};
  Set<String> _selectedBuilding = {};

  // Store IDs for API submission
  int? _selectedRegionId;
  int? _selectedCityId;
  int? _selectedStreetId;
  // ignore: unused_field
  int? _selectedBuildingId;

  // 🆕 Cache для результатов поиска городов (city name -> city id)
  // Используется для получения ID города при выборе из диалога
  Map<String, int> _lastCitiesSearchResults = {};

  // 🆕 Cache для результатов поиска улиц (street name -> street id)
  // Используется для получения ID улицы при выборе из диалога
  Map<String, int> _lastStreetsSearchResults = {};

  // 🆕 Cache для subregion ID из результатов поиска (street name -> region_id)
  // Используется для получения ID суб-региона при выборе улицы
  Map<String, int?> _lastStreetsSubregionResults = {};

  // =============== Validation Errors ===============
  Map<String, String?> _fieldErrors = {}; // Stores validation error messages

  @override
  void initState() {
    super.initState();

    // 🔧 ВАЖНО: Инициализируем _cities как пустой список
    // Города будут загружены ТОЛЬКО с API после выбора региона
    _cities = [];
    // log.d(
    //   '✅ initState: _cities инициализирован как пустой список (будут загружены с API)',
    // );

    // Проверить режим редактирования
    _isEditMode = widget.advertId != null;
    // log.d('🔧 DynamicFilter initState:');
    // log.d('   - advertId: ${widget.advertId}');
    // log.d('   - categoryId: ${widget.categoryId}');
    // log.d('   - isEditMode: $_isEditMode');

    // Используем разные сценарии инициализации для создания vs редактирования
    if (_isEditMode) {
      // При редактировании: сначала загрузить данные, потом атрибуты
      // log.d('   → Starting initialization for EDITING mode');
      _initializeForEditing();
    } else {
      // При создании: загрузить атрибуты, контакты, регионы
      // log.d('   → Starting initialization for CREATION mode');
      _initializeForCreation();
    }
  }

  /// Инициализация для создания нового объявления
  Future<void> _initializeForCreation() async {
    // ✅ Load attributes and support data concurrently
    await Future.wait([_loadAttributes(), _loadUserContacts(), _loadRegions()]);

    // Автозаполнение для тестирования (after all data loaded)
    Future.delayed(const Duration(milliseconds: 500), () {
      _autoFillFormForTesting();
    });
  }

  /// Инициализация для редактирования объявления
  Future<void> _initializeForEditing() async {
    // log.d(
    //   '📝 [EDIT MODE] Step 1: Loading advert data FIRST to get category...',
    // );

    // 1️⃣ СНАЧАЛА загружаем только ID категории из объявления
    // НЕ заполняем данные в контроллеры еще - им нужны атрибуты
    await _loadAdvertCategoryOnly();

    // log.d(
    //   '📝 [EDIT MODE] Step 2: Now loading attributes for category $_editAdvertCategoryId...',
    // );

    // 2️⃣ Теперь загружаем атрибуты для ПРАВИЛЬНОЙ категории
    await _loadAttributes();

    // log.d(
    //   '📝 [EDIT MODE] Step 3: Attributes loaded. Now loading full advert data...',
    // );

    // ✅ Add delay for setState() to process attribute changes in UI
    await Future.delayed(const Duration(milliseconds: 100));

    // 3️⃣ ПОТОМ загружаем все данные объявления (используем правильные атрибуты)
    await _loadAdvertDataForEditing();

    // log.d(
    //   '📝 [EDIT MODE] Step 4: Repopulating controllers after attributes + advert data loaded...',
    // );

    // 4️⃣ Пересоздаем контроллеры с правильными значениями
    if (_isEditMode && _editAdvertData != null) {
      _repopulateControllersAfterAttributesLoaded();
    }

    // log.d('📝 [EDIT MODE] Step 5: Loading contacts and regions...');

    // 5️⃣ Загружаем вспомогательные данные
    await _loadUserContacts();
    await _loadRegions();

    // log.d('📝 [EDIT MODE] Initialization complete!');
  }

  /// Перезагружает данные фильтра при восстановлении подключения
  Future<void> _reloadFilterData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      if (_isEditMode) {
        // При редактировании: перезагружаем данные объявления и атрибуты
        await Future.wait([
          _loadAttributes(),
          _loadUserContacts(),
          _loadRegions(),
        ]);
        // Если есть данные объявления, обновляем их
        if (widget.advertId != null) {
          await _loadAdvertDataForEditing();
          _repopulateControllersAfterAttributesLoaded();
        }
      } else {
        // При создании: перезагружаем атрибуты и данные поддержки
        await Future.wait([
          _loadAttributes(),
          _loadUserContacts(),
          _loadRegions(),
        ]);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // log.d('Error reloading filter data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _telegramController.dispose();
    _whatsappController.dispose();
    _buildingController.dispose();
    _controllers.forEach((key, controller) => controller.dispose());
    _controllers.clear();
    super.dispose();
  }

  /// Маппинг стилей фильтров: Style (просмотр) → Style2 (подача объявления)
  /// Согласно ui_filter_styles.md, при подаче объявления используются разные стили
  ///
  /// ВАЖНО: Style I (скрытые чекбоксы) → Style B (чекбоксы) для полей:
  /// - Возможен торг
  /// - Без комиссии
  /// - Возможность обмена
  /// Эти поля имеют is_title_hidden=true и is_multiple=true
  String _getSubmissionStyle(String apiStyle) {
    // API returns Style for viewing listings, but we need Style2 for submission form
    const styleMapping = {
      'A': 'A1', // Текстовое поле → Input
      'B': 'B', // Чекбокс → без изменений
      'C': 'C', // Да/Нет → без изменений
      'D': 'D1', // Множественный выбор → Popup/CheckboxList
      'E': 'E1', // Диапазон целых → Range (от/до)
      'F': 'F', // Popup множественный → без изменений
      'G': 'G1', // Числовое поле → Input (number)
      'H': 'H', // Текстовое поле → без изменений
      'I': 'B', // Скрытые чекбоксы → Style B (чекбокс) для подачи объявления
      'manual': 'manual',
    };
    return styleMapping[apiStyle] ?? apiStyle;
  }

  /// Получить ID атрибута "Вам предложат цену" безопасно
  /// Гарантирует наличие ID, так как атрибут всегда добавляется в _loadAttributes()
  int? _getOfferPriceAttributeId() {
    // Получаем через resolver (уже исправлено чтобы возвращать null для категорий без атрибута)
    var id = _attributeResolver.getOfferPriceAttributeId();
    if (id != null) {
      return id;
    }

    // Fallback: ищем в _attributes по названию "Вам предложат цену"
    // Это только для недвижимости когда метаданные загружены неполно
    try {
      final attr = _attributes.firstWhere(
        (a) => a.title == 'Вам предложат цену',
      );
      return attr.id;
    } catch (_) {
      // Если не нашли по названию, значит этот атрибут не существует в этой категории
      // ВАЖНО: НЕ ищем "любой булевый атрибут" - это вызовет ошибку "Attribute doesn't belong to category"
      // При возврате null, код будет правильно пропускать добавление этого атрибута для Jobs и т.д.
      return null;
    }
  }

  Future<void> _loadAttributes() async {
    try {
      // Определяем категорию: из редактирования, затем из параметра, затем по умолчанию 2
      final categoryId = _editAdvertCategoryId ?? widget.categoryId ?? 2;
      // log.d('');
      // log.d('🎯 _loadAttributes() called:');
      // log.d('   - _editAdvertCategoryId: $_editAdvertCategoryId');
      // log.d('   - widget.categoryId: ${widget.categoryId}');
      // log.d('   - Using categoryId: $categoryId');
      // log.d('   Loading attributes for category: $categoryId');
      final token = TokenService.currentToken;

      // ИСПОЛЬЗУЕМ /adverts/create ВМЕСТО /meta/filters
      // Этот endpoint возвращает правильные ID атрибутов для конкретной категории
      // и включает обязательный атрибут "Вам предложат цену" (для категории 3)
      List<Attribute> loadedAttributes;

      try {
        // Пытаемся получить атрибуты через /adverts/create
        loadedAttributes = await ApiService.getAdvertCreationAttributes(
          categoryId: categoryId,
          token: token,
        );
        // log.d();
      } catch (e) {
        // log.d();
        // Fallback на старый метод
        final response = await ApiService.getMetaFilters(
          categoryId: categoryId,
          token: token,
        );
        loadedAttributes = response.filters;
        // log.d();
      }

      // Логируем загруженные атрибуты
      // (debug вывод отключён)

      // Convert to mutable list and apply Style → Style2 mapping for submission form
      var mutableFilters = List<Attribute>.from(loadedAttributes);

      // Apply submission style mapping (Style → Style2)
      // Save both original style and transformed style
      mutableFilters = mutableFilters.map((attr) {
        final submissionStyle = _getSubmissionStyle(attr.style);
        // log.d();
        // Create new attribute with both styles preserved
        return Attribute(
          id: attr.id,
          title: attr.title,
          isFilter: attr.isFilter,
          isRange: attr.isRange,
          isMultiple: attr.isMultiple,
          isHidden: attr.isHidden,
          isRequired: attr.isRequired,
          isTitleHidden: attr.isTitleHidden,
          isSpecialDesign: attr.isSpecialDesign,
          isPopup: attr.isPopup,
          isMaxValue: attr.isMaxValue,
          maxValue: attr.maxValue,
          vmText: attr.vmText,
          dataType: attr.dataType,
          style: attr.style, // Keep original API style
          styleSingle: attr.styleSingle,
          style2: submissionStyle, // Add transformed style for submission
          order: attr.order,
          values: attr.values,
        );
      }).toList();

      // Инициализируем resolver для динамического поиска ID атрибутов
      _attributeResolver = AttributeResolver(mutableFilters);
      // log.d('');
      // log.d('📋 ═══════════════════════════════════════════════════════');
      // log.d('📋 CATEGORY $categoryId - ATTRIBUTES LOADED');
      // log.d('📋 ═══════════════════════════════════════════════════════');
      _attributeResolver.debugPrintAll(prefix: '   ');
      _attributeResolver.debugPrintCriticalAttributes(prefix: '   ');
      // log.d('📋 ═══════════════════════════════════════════════════════');
      // log.d('');

      // Получаем ID критических атрибутов динамически
      var offerPriceAttrId = _attributeResolver.getOfferPriceAttributeId();

      // Если не нашли по имени/типу, ищем по известным ID для недвижимости
      // и используем первый найденный или создаём новый
      if (offerPriceAttrId == null) {
        // log.d();
        // log.d();

        // Попробуем найти по известным ID (в случае если API поменял названия)
        const knownOfferPriceIds = [1048, 1050, 1051, 1052, 1128, 1130];
        for (final id in knownOfferPriceIds) {
          if (mutableFilters.any((a) => a.id == id)) {
            offerPriceAttrId = id;
            // log.d('   ✅ Found by known ID: $id');
            break;
          }
        }
      }

      // Если всё ещё не нашли, создаём новый с дефолтным ID для этой категории
      if (offerPriceAttrId == null) {
        // log.d();

        // Используем ID в зависимости от категории (fallback)
        if (categoryId == 2) {
          offerPriceAttrId = 1048; // Продажа квартир
        } else if (categoryId == 3) {
          offerPriceAttrId = 1050; // Долгосрочная аренда квартир
        } else if (categoryId == 5) {
          offerPriceAttrId = 1051; // Продажа комнат
        } else if (categoryId == 6) {
          offerPriceAttrId = 1052; // Долгосрочная аренда комнат
        } else {
          // Для всех остальных категорий используем базовый ID
          offerPriceAttrId = 2000 + categoryId;
          // log.d();
        }
      }

      // Проверяем наличие обязательного атрибута "Вам предложат цену"
      final hasOfferPriceAttr = mutableFilters.any(
        (a) => a.id == offerPriceAttrId,
      );

      if (!hasOfferPriceAttr) {
        // log.d();
        // НЕ создаём искусственный атрибут - это вызовет ошибку валидации на API!
        // Он будет пропущен при отправке, так как его нет в _attributes
      } else {
        // log.d('✅ Attribute $offerPriceAttrId already exists in filters');
      }

      if (mounted) {
        setState(() {
          _attributes = mutableFilters;
          _isLoading = false;

          // 🔧 CRITICAL FIX: Clean up selected values that don't exist in this category
          // This prevents sending attributes from another category
          // (e.g., when editing an advert from one category, then switching to another)
          final validAttributeIds = mutableFilters.map((a) => a.id).toSet();
          _selectedValues.removeWhere(
            (attrId, _) => !validAttributeIds.contains(attrId),
          );

          // Инициализируем "Вам предложат цену" на false по умолчанию
          // Значение остаётся false до тех пор, пока пользователь не нажмёт чекбокс
          if (offerPriceAttrId != null &&
              mutableFilters.any((a) => a.id == offerPriceAttrId)) {
            _selectedValues[offerPriceAttrId] = false;
          }
        });
      }

      // Load category name
      _loadCategoryInfo();
    } catch (e) {
      // log.d('Error loading attributes from API: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Retry after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _loadAttributes();
      });
    }
  }

  /// 🔍 Загружает ТОЛЬКО ID категории из объявления
  /// Используется при редактировании для определения правильной категории перед загрузкой атрибутов
  Future<void> _loadAdvertCategoryOnly() async {
    if (widget.advertId == null) return;

    try {
      final token = TokenService.currentToken;
      final advertId = widget.advertId!;

      log.d('📂 [CATEGORY] Loading category ID from advert $advertId...');

      final response = await ApiService.get('/adverts/$advertId', token: token);

      // Парсим ответ API
      late final Map<String, dynamic> advertData;
      if (response.containsKey('data')) {
        final data = response['data'];
        if (data is List && data.isNotEmpty) {
          advertData = data[0] as Map<String, dynamic>;
        } else if (data is Map<String, dynamic>) {
          advertData = data;
        } else {
          advertData = response;
        }
      } else {
        advertData = response;
      }

      // ✅ ИЗВЛЕКАЕМ КАТЕГОРИЮ ИЗ ОБЪЯВЛЕНИЯ
      int? extractedCategoryId;

      // Вариант 1: category_id
      if (advertData.containsKey('category_id') &&
          advertData['category_id'] != null) {
        extractedCategoryId = advertData['category_id'] as int;
        log.d('   ✅ Found category_id = $extractedCategoryId');
      }

      // Вариант 2: если category это Map с id
      if (extractedCategoryId == null &&
          advertData.containsKey('category') &&
          advertData['category'] is Map) {
        final categoryData = advertData['category'] as Map<String, dynamic>;
        if (categoryData.containsKey('id')) {
          extractedCategoryId = categoryData['id'] as int;
          log.d('   ✅ Found category.id = $extractedCategoryId');
        }
      }

      // Вариант 3: Если это передано как widget.categoryId (параметр навигации)
      if (extractedCategoryId == null && widget.categoryId != null) {
        extractedCategoryId = widget.categoryId;
        log.d('   ✅ Using widget.categoryId = $extractedCategoryId (fallback)');
      }

      // Установляем найденную категорию
      if (extractedCategoryId != null) {
        _editAdvertCategoryId = extractedCategoryId;
        log.d('   ✅ SET _editAdvertCategoryId = $_editAdvertCategoryId');
      } else {
        log.d('   ⚠️ Could not find category ID, will use default = 2');
        _editAdvertCategoryId = 2; // Default fallback
      }
    } catch (e) {
      log.d('   ❌ Error loading category ID: $e');
      _editAdvertCategoryId = 2; // Fallback
    }
  }

  /// Загрузить данные объявления для редактирования
  Future<void> _loadAdvertDataForEditing() async {
    if (widget.advertId == null) return;

    try {
      setState(() => _isLoadingEditData = true);

      final token = TokenService.currentToken;
      final advertId = widget.advertId!;

      // Получаем полные данные объявления через публичный эндпоинт
      // В API есть /adverts/{id} который возвращает все необходимые данные
      // log.d('📥 Loading advert data for editing: $advertId');

      final response = await ApiService.get('/adverts/$advertId', token: token);

      // Парсим ответ API: response всегда Map<String, dynamic>
      late final Map<String, dynamic> advertData;
      if (response.containsKey('data')) {
        final data = response['data'];
        if (data is List && data.isNotEmpty) {
          advertData = data[0] as Map<String, dynamic>;
        } else if (data is Map<String, dynamic>) {
          advertData = data;
        } else {
          advertData = response;
        }
      } else {
        advertData = response;
      }

      // log.d('📦 Loaded advert data: ${advertData.keys.toList()}');
      // log.d('📦 Full advert type data: ${advertData['type']}');

      // 🔄 КАТЕГОРИЯ УЖЕ ЗАГРУЖЕНА В _loadAdvertCategoryOnly()
      // Используем это значение для правильного парсинга атрибутов
      // log.d('   Using _editAdvertCategoryId = $_editAdvertCategoryId from previous load');

      if (mounted) {
        setState(() {
          _editAdvertData = advertData;
          _isLoadingEditData = false;
        });
      }

      // Заполняем основные поля формы
      await Future.delayed(const Duration(milliseconds: 100));

      if (advertData.containsKey('name')) {
        _titleController.text = advertData['name'] as String? ?? '';
        // log.d('✅ Filled title: ${advertData['name']}');
      }

      if (advertData.containsKey('description')) {
        _descriptionController.text =
            advertData['description'] as String? ?? '';
        // log.d('✅ Filled description');
      }

      if (advertData.containsKey('price')) {
        final price = advertData['price'];
        if (price != null) {
          _priceController.text = price.toString();
          // log.d('✅ Filled price: $price');
        }
      }

      if (advertData.containsKey('address')) {
        final fullAddress = advertData['address'] as String? ?? '';

        // 🔧 Парсим адрес при редактировании
        // API возвращает адрес как строка: "г. Донецк, ул. Бутовская" или "Область, г. Донецк, ул. Бутовская, д. 70"
        await _populateAddressFieldsFromEdit(fullAddress);
        // log.d('✅ Filled address: $fullAddress');
      }

      // Заполняем контакты если есть (может быть в разных местах)
      String contactName = '';
      if (advertData.containsKey('contact_name')) {
        contactName = advertData['contact_name'] as String? ?? '';
      } else if (advertData.containsKey('user') && advertData['user'] is Map) {
        final user = advertData['user'] as Map<String, dynamic>;
        if (user.containsKey('name')) {
          contactName = user['name'] as String? ?? '';
        }
      }

      if (contactName.isNotEmpty) {
        // 📝 Парсим полное имя на отдельные части - в поле только первое слово (имя)
        final nameParts = contactName.trim().split(RegExp(r'\s+'));
        final firstName = nameParts.isNotEmpty ? nameParts.first : contactName;
        _contactNameController.text = firstName;
        // log.d('✅ Filled contact name (first name only): $firstName');
      }

      // ✅ ЗАПОЛНЯЕМ АТРИБУТЫ ИЗ ОБЪЯВЛЕНИЯ
      _populateAttributesFromAdvert(advertData);

      // ✅ ЗАГРУЖАЕМ ИЗОБРАЖЕНИЯ ИЗ ОБЪЯВЛЕНИЯ
      await _loadAdvertImages(advertData);

      // ✅ ЗАПОЛНЯЕМ КОНТАКТЫ ИЗ ОБЪЯВЛЕНИЯ
      _populateContactsFromAdvert(advertData);

      // log.d('✅ Advert data loaded successfully');
    } catch (e) {
      // log.d('❌ Error loading advert data: $e');
      if (mounted) {
        setState(() => _isLoadingEditData = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
      }
    }
  }

  /// 🔧 Заполняет все поля адреса при редактировании объявления
  /// Парсит адрес и заполняет контроллеры: область, город, улица, номер дома
  /// Также вызывает загрузку данных для каждого уровня иерархии
  Future<void> _populateAddressFieldsFromEdit(String fullAddress) async {
    try {
      if (fullAddress.isEmpty) {
        log.d('⚠️ Empty address provided');
        return;
      }

      log.d('🔍 Populating address fields from: $fullAddress');

      // Адрес может быть в разных форматах:
      // 1. "г. Донецк, ул. Донецкая" - 2 части (город, улица)
      // 2. "г. Донецк, ул. Донецкая, д. 70" - 3 части (город, улица, дом)
      // 3. "Донецкая Народная респ., г. Донецк, ул. Донецкая, д. 70" - 4 части (область, город, улица, дом)

      final parts = fullAddress.split(',').map((p) => p.trim()).toList();

      log.d('   Parts: $parts (${parts.length} parts)');

      if (parts.isEmpty) return;

      // ✅ ВАРИАНТ 1: 4 части - полный адрес с областью
      if (parts.length == 4) {
        log.d('   📍 Full address with region detected');
        await _selectAddressFromParts(
          region: parts[0],
          city: parts[1],
          street: parts[2],
          building: parts[3],
        );
      }
      // ✅ ВАРИАНТ 2: 3 части - адрес с номером дома (без области)
      else if (parts.length == 3) {
        log.d('   📍 Address with building detected');
        await _selectAddressFromParts(
          city: parts[0],
          street: parts[1],
          building: parts[2],
        );
      }
      // ✅ ВАРИАНТ 3: 2 части - только город и улица
      else if (parts.length == 2) {
        log.d('   📍 Address without building detected');
        await _selectAddressFromParts(city: parts[0], street: parts[1]);
      }

      log.d('✅ Address fields populated successfully');
    } catch (e) {
      log.d('❌ Error populating address fields: $e');
    }
  }

  /// 🔧 Выбирает адрес из составляющих частей
  /// Заполняет контроллеры и _selected* переменные
  Future<void> _selectAddressFromParts({
    String? region,
    String? city,
    String? street,
    String? building,
  }) async {
    try {
      // ✅ ЗАПОЛНЯЕМ КОНТРОЛЛЕРЫ СРАЗУ
      if (region != null && region.isNotEmpty) {
        setState(() => _regionController.text = region);
        log.d('   ✅ Set _regionController = "$region"');
      }

      if (city != null && city.isNotEmpty) {
        setState(() => _cityController.text = city);
        log.d('   ✅ Set _cityController = "$city"');
      }

      if (street != null && street.isNotEmpty) {
        setState(() => _streetController.text = street);
        log.d('   ✅ Set _streetController = "$street"');
      }

      if (building != null && building.isNotEmpty) {
        setState(() => _buildingController.text = building);
        log.d('   ✅ Set _buildingController = "$building"');
      }

      // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ РЕГИОН (если он указан)
      if (region != null && region.isNotEmpty) {
        await _selectRegionByName(region);

        // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ ГОРОД (если регион выбран)
        if (city != null && city.isNotEmpty && _selectedRegionId != null) {
          await _selectCityByName(city);

          // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ УЛИЦУ (если город выбран)
          if (street != null && street.isNotEmpty && _selectedCityId != null) {
            await _selectStreetByName(street);

            // ✅ ЗАГРУЖАЕМ И ВЫБИРАЕМ НОМ ЕР ДОМА (если улица выбрана)
            if (building != null &&
                building.isNotEmpty &&
                _selectedStreetId != null) {
              await _selectBuildingByName(building);
            }
          }
        }
      }
    } catch (e) {
      log.d('❌ Error selecting address from parts: $e');
    }
  }

  /// 🔍 找ет и выбирает регион по названию
  Future<void> _selectRegionByName(String regionName) async {
    try {
      final token = TokenService.currentToken;

      // Загружаем все регионы если их нет
      if (_regions.isEmpty) {
        final response = await AddressService.searchAddresses(
          query: 'р',
          token: token,
          types: ['region'],
        );

        final uniqueRegions = <String, int>{};
        for (final result in response.data) {
          if (result.main_region != null) {
            uniqueRegions[result.main_region!.name] = result.main_region!.id;
          }
        }

        setState(() {
          _regions = uniqueRegions.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
        log.d('   📦 Loaded ${_regions.length} regions from API');
      }

      // Ищем регион по названию (точное совпадение или частичное)
      final region = _regions.firstWhere(
        (r) => (r['name'] as String).toLowerCase() == regionName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
          return _regions.firstWhere(
            (r) => (r['name'] as String).toLowerCase().contains(
              regionName.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (region.isNotEmpty) {
        setState(() {
          _selectedRegionId = region['id'] as int;
          _selectedRegion.clear();
          _selectedRegion.add(region['name'] as String);
        });
        log.d('   ✅ Selected region: ${region['name']} (ID: ${region['id']})');
      } else {
        log.d('   ⚠️ Region "$regionName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting region: $e');
    }
  }

  /// 🔍 Ищет и выбирает город по названию
  Future<void> _selectCityByName(String cityName) async {
    try {
      if (_selectedRegionId == null) {
        log.d('   ⚠️ Cannot select city: no region selected');
        return;
      }

      final token = TokenService.currentToken;

      // Загружаем города для выбранного региона
      // Получить ВСЕ города для выбранного региона
      final response = await AddressService.searchAddresses(
        query: '   ', // Минимум 3 символа для API (пустой поиск)
        token: token,
        types: ['city'],
        filters: {
          'main_region_id': _selectedRegionId, // Только города этого региона
        },
      );

      final uniqueCities = <String, int>{};
      for (final result in response.data) {
        if (result.city != null) {
          uniqueCities[result.city!.name] = result.city!.id;
        }
      }

      setState(() {
        _cities = uniqueCities.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();

        log.d(
          '✅ Loaded ${_cities.length} cities for region ID $_selectedRegionId',
        );
      });

      // Ищем город по названию
      final city = _cities.firstWhere(
        (c) => (c['name'] as String).toLowerCase() == cityName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
          return _cities.firstWhere(
            (c) => (c['name'] as String).toLowerCase().contains(
              cityName.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (city.isNotEmpty) {
        setState(() {
          _selectedCityId = city['id'] as int;
          _selectedCity.clear();
          _selectedCity.add(city['name'] as String);
        });
        log.d('   ✅ Selected city: ${city['name']} (ID: ${city['id']})');
      } else {
        log.d('   ⚠️ City "$cityName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting city: $e');
    }
  }

  /// 🔍 Ищет и выбирает улицу по названию
  Future<void> _selectStreetByName(String streetName) async {
    try {
      if (_selectedCityId == null) {
        log.d('   ⚠️ Cannot select street: no city selected');
        return;
      }

      final token = TokenService.currentToken;

      // Загружаем улицы для выбранного города
      final response = await AddressService.searchAddresses(
        query: 'у',
        token: token,
        types: ['street'],
        filters: _selectedCityId != null ? {'city_id': _selectedCityId} : null,
      );

      final uniqueStreets = <String, int>{};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          uniqueStreets[result.street!.name] = result.street!.id;
        }
      }

      setState(() {
        _streets = uniqueStreets.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();
      });
      log.d('   📦 Loaded ${_streets.length} streets for city');

      // Ищем улицу по названию
      final street = _streets.firstWhere(
        (s) => (s['name'] as String).toLowerCase() == streetName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
          return _streets.firstWhere(
            (s) => (s['name'] as String).toLowerCase().contains(
              streetName.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (street.isNotEmpty) {
        setState(() {
          _selectedStreetId = street['id'] as int;
          _selectedStreet.clear();
          _selectedStreet.add(street['name'] as String);
        });
        log.d('   ✅ Selected street: ${street['name']} (ID: ${street['id']})');
      } else {
        log.d('   ⚠️ Street "$streetName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting street: $e');
    }
  }

  /// 🔍 Ищет и выбирает номер дома по названию
  Future<void> _selectBuildingByName(String buildingName) async {
    try {
      if (_selectedStreetId == null) {
        log.d('   ⚠️ Cannot select building: no street selected');
        return;
      }

      final token = TokenService.currentToken;

      // Загружаем номера домов для выбранной улицы
      final response = await AddressService.searchAddresses(
        query: '1',
        token: token,
        types: ['building'],
        filters: _selectedStreetId != null
            ? {'street_id': _selectedStreetId}
            : null,
      );

      final uniqueBuildings = <String, int>{};
      for (final result in response.data) {
        if (result.street?.id == _selectedStreetId && result.building != null) {
          uniqueBuildings[result.building!.name] = result.building!.id;
        }
      }

      setState(() {
        _buildings = uniqueBuildings.entries
            .map((e) => {'name': e.key, 'id': e.value})
            .toList();
      });
      log.d('   📦 Loaded ${_buildings.length} buildings for street');

      // Ищем номер дома по названию
      final building = _buildings.firstWhere(
        (b) =>
            (b['name'] as String).toLowerCase() == buildingName.toLowerCase(),
        orElse: () {
          // Если точного совпадения нет, ищем по началу строки
          return _buildings.firstWhere(
            (b) => (b['name'] as String).toLowerCase().contains(
              buildingName.toLowerCase(),
            ),
            orElse: () => {},
          );
        },
      );

      if (building.isNotEmpty) {
        setState(() {
          _selectedBuilding.clear();
          _selectedBuilding.add(building['name'] as String);
        });
        log.d('   ✅ Selected building: ${building['name']}');
      } else {
        log.d('   ⚠️ Building "$buildingName" not found in list');
      }
    } catch (e) {
      log.d('   ❌ Error selecting building: $e');
    }
  }

  /// 🔧 Парсит адрес из API при редактировании объявления
  /// API возвращает адрес строкой: "г. Донецк, ул. Бутовская" или "г. Донецк, ул. Бутовская, 1А"
  /// Нужно распарсить и выделить номер дома в _selectedBuilding
  void _parseAddressForEdit(String fullAddress) {
    try {
      if (fullAddress.isEmpty) return;

      // Адрес имеет формат: "город, улица[, номер_дома]"
      // Примеры:
      // "г. Донецк, ул. Бутовская" - БЕЗ номера дома
      // "г. Донецк, пр-кт 301-й Донецкой дивизии, 1А" - С номером дома

      final parts = fullAddress.split(',').map((p) => p.trim()).toList();

      log.d('🔍 Parsing address: $fullAddress');
      log.d('   Parts: $parts (${parts.length} parts)');

      if (parts.isEmpty) return;

      // Логика парсинга:
      // [0] = город (г. Донецк)
      // [1] = улица (ул. Бутовская)
      // [2] = номер дома (1А) - ОПЦИОНАЛЬНО

      String? buildingNumber;

      if (parts.length >= 3) {
        // Если 3+ части, последняя - это номер дома
        buildingNumber = parts.last;
        log.d('   ✅ Found building number: "$buildingNumber" (last part)');
      } else if (parts.length == 2) {
        // Только 2 части - нет номера дома в API
        log.d('   ⚠️ No building number in address (only 2 parts)');
        // Это нормально, может быть просто "г. Донецк, ул. Бутовская"
      }

      // Заполняем _selectedBuilding если найден номер дома
      if (buildingNumber != null && buildingNumber.isNotEmpty) {
        setState(() {
          _selectedBuilding.clear();
          _selectedBuilding.add(
            buildingNumber!,
          ); // ! для force unwrap, так как проверили что not null
        });
        log.d('   ✅ Set _selectedBuilding = {"$buildingNumber"}');
      } else {
        // Если номера дома нет, делаем _selectedBuilding пустым
        setState(() {
          _selectedBuilding.clear();
        });
        log.d('   ℹ️ _selectedBuilding cleared (no building number)');
      }
    } catch (e) {
      log.d('❌ Error parsing address: $e');
    }
  }

  /// 🔧 Заполняет атрибуты формы из загруженного объявления
  /// Парсит структуру attributes из API ответа и заполняет _selectedValues
  void _populateAttributesFromAdvert(Map<String, dynamic> advertData) {
    if (!advertData.containsKey('attributes')) {
      log.d('ℹ️ No attributes found in advert data');
      return;
    }

    try {
      final attributesData = advertData['attributes'];

      if (attributesData is Map<String, dynamic>) {
        log.d('🔍 Populating attributes from advert...');

        // ✅ Обратное маппирование value_selected - найти к каким атрибутам относятся ID значений
        if (attributesData.containsKey('value_selected')) {
          final valueSelected = attributesData['value_selected'];
          if (valueSelected is List && _attributes.isNotEmpty) {
            log.d('   value_selected IDs: $valueSelected');

            // Для каждого ID значения найти атрибут по его значениям
            for (final valueId in valueSelected) {
              // Поищем в _attributes, какой атрибут содержит это значение
              for (final attr in _attributes) {
                final matchingValue = attr.values.firstWhere(
                  (val) => val.id == valueId,
                  orElse: () => const Value(id: 0, value: ''),
                );

                if (matchingValue.id != 0) {
                  // Нашли! Добавляем это значение в selectedValues для этого атрибута
                  setState(() {
                    if (_selectedValues[attr.id] is Set<String>) {
                      (_selectedValues[attr.id] as Set<String>).add(
                        matchingValue.value,
                      );
                    } else {
                      _selectedValues[attr.id] = {matchingValue.value};
                    }
                  });
                  log.d(
                    '   ✅ Attr ${attr.id} "${attr.title}": added value "${matchingValue.value}"',
                  );
                  break; // Found, move to next value ID
                }
              }
            }
          }
        }

        // ✅ Заполняем values - это числовые/строковые атрибуты с поддержкой диапазонов
        if (attributesData.containsKey('values')) {
          final values = attributesData['values'];
          if (values is Map<String, dynamic>) {
            log.d('   values: $values');

            values.forEach((attrIdStr, valueData) {
              try {
                final attrId = int.parse(attrIdStr);
                final attr = _attributes.firstWhere(
                  (a) => a.id == attrId,
                  orElse: () =>
                      Attribute(id: 0, title: '', order: 0, values: []),
                );

                if (attr.id != 0) {
                  // Найден атрибут
                  if (valueData is Map<String, dynamic>) {
                    // Проверяем есть ли это диапазон (max_value) или просто значение
                    if (valueData.containsKey('max_value')) {
                      // Это диапазон (e.g. пол, площадь)
                      setState(() {
                        _selectedValues[attrId] = {
                          'min': valueData['value'],
                          'max': valueData['max_value'],
                        };
                      });
                      log.d(
                        '   ✅ Attr $attrId: range value=${valueData['value']}, max=${valueData['max_value']}',
                      );
                    } else if (valueData.containsKey('value')) {
                      // Простое числовое значение
                      final value = valueData['value'];

                      // Для булевских атрибутов (like оферт 1048)
                      if (attr.dataType == 'boolean') {
                        setState(() {
                          _selectedValues[attrId] =
                              (value == 1 || value == true);
                        });
                        log.d('   ✅ Attr $attrId: boolean value=$value');
                      } else {
                        // Для текстовых атрибутов сохраняем в controller
                        if (_controllers[attrId] != null) {
                          _controllers[attrId]!.text = value.toString();
                        } else {
                          setState(() {
                            _selectedValues[attrId] = value;
                          });
                        }
                        log.d('   ✅ Attr $attrId: value=$value');
                      }
                    }
                  } else {
                    // Простое значение без структуры
                    setState(() {
                      _selectedValues[attrId] = valueData;
                    });
                    log.d('   ✅ Attr $attrId: simple value=$valueData');
                  }
                } else {
                  log.d(
                    '   ⚠️ Attribute ID $attrId not found in loaded attributes',
                  );
                }
              } catch (e) {
                log.d('   ⚠️ Error parsing attribute "$attrIdStr": $e');
              }
            });
          }
        }

        log.d('✅ Attributes population complete');
      } else if (attributesData is List) {
        log.d('ℹ️ Attributes returned as list format');
        log.d('   List length: ${(attributesData as List).length}');

        // Обработка List формата: [{id, value, max_value, values_id}, ...]
        try {
          final attributesList = attributesData as List<dynamic>;
          // ⚠️ НЕ переносим старые значения! Начинаем с чистого листа
          final tempSelectedValues = <int, dynamic>{};

          log.d('   _attributes available: ${_attributes.length}');
          if (_attributes.isEmpty) {
            log.d('   ⚠️ WARNING: _attributes is empty! Cannot process values');
            return;
          }

          // Отслеживаем какие атрибуты обработаны
          final processedAttrIds = <int>{};

          for (final attrItem in attributesList) {
            if (attrItem is Map<String, dynamic> &&
                attrItem.containsKey('id')) {
              final attrId = attrItem['id'] as int?;
              if (attrId == null) continue;

              processedAttrIds.add(attrId);

              // Найти атрибут в loaded _attributes
              final attr = _attributes.firstWhere(
                (a) => a.id == attrId,
                orElse: () => Attribute(id: 0, title: '', order: 0, values: []),
              );

              if (attr.id == 0) {
                log.d('   ⚠️ Attr $attrId not found in _attributes');
                continue;
              }

              log.d('   Processing Attr $attrId "${attr.title}"...');

              // ✅ CASE 1: values_id - для множественных выборов (D1, F типы)
              if (attrItem.containsKey('values_id')) {
                final valuesId = attrItem['values_id'];
                if (valuesId is List && valuesId.isNotEmpty) {
                  log.d('      ✅ Has values_id: $valuesId');

                  final selectedSet = <String>{};
                  for (final valueId in valuesId) {
                    final valueInt = valueId is int
                        ? valueId
                        : (int.tryParse(valueId.toString()) ?? 0);

                    // Найти value по ID в attr.values
                    final matchingValue = attr.values.firstWhere(
                      (val) => val.id == valueInt,
                      orElse: () => const Value(id: 0, value: ''),
                    );

                    if (matchingValue.id != 0) {
                      selectedSet.add(matchingValue.value);
                    }
                  }

                  if (selectedSet.isNotEmpty) {
                    // 🔧 SPECIAL: Если это чекбокс (I тип) - преобразовать в boolean
                    if (attr.styleSingle == 'I') {
                      tempSelectedValues[attrId] =
                          true; // Если значение есть - true
                      log.d('      ✅ I-type checkbox: Set to TRUE');
                    } else {
                      // C1, D1, F типы - оставить как Set
                      tempSelectedValues[attrId] = selectedSet;
                      log.d(
                        '      ✅ Added to tempSelectedValues: $selectedSet',
                      );
                    }
                  } else {
                    log.d(
                      '      ⚠️ values_id пусто или не найдено в values - пропускаем',
                    );
                  }
                } else {
                  log.d(
                    '      ⚠️ values_id отсутствует или пусто - пропускаем',
                  );
                }
              }
              // ✅ CASE 2: value + max_value - для диапазонов (E1 типы)
              else if (attrItem.containsKey('max_value') &&
                  attrItem['max_value'] != null) {
                final minVal = attrItem['value'];
                final maxVal = attrItem['max_value'];

                tempSelectedValues[attrId] = {'min': minVal, 'max': maxVal};
                log.d('      ✅ Range: $minVal - $maxVal');
              }
              // ✅ CASE 3: value - для простых значений (G1, H типы)
              else if (attrItem.containsKey('value') &&
                  attrItem['value'] != null) {
                final value = attrItem['value'];
                tempSelectedValues[attrId] = value;
                log.d('      ✅ Value: $value (type: ${value.runtimeType})');
              }
            }
          }

          log.d('   Processed ${processedAttrIds.length} attributes from API');
          log.d(
            '   tempSelectedValues prepared: ${tempSelectedValues.length} items',
          );
          log.d('   Content: $tempSelectedValues');

          // 🔄 Один раз setState() с ВСЕ значения
          if (tempSelectedValues.isNotEmpty) {
            setState(() {
              _selectedValues = tempSelectedValues;
            });
            log.d(
              '✅ setState() called. _selectedValues now has ${_selectedValues.length} items',
            );
          }

          log.d('✅ List format attributes processed');
        } catch (e) {
          log.d('❌ Error processing list format: $e');
        }
      }
    } catch (e) {
      log.d('❌ Error populating attributes: $e');
    }
  }

  /// � Пересоздает контроллеры с правильными значениями ПОСЛЕ загрузки атрибутов
  /// Это нужно для того чтобы UI отобразил предзаполненные значения
  void _repopulateControllersAfterAttributesLoaded() {
    try {
      log.d('🔄 Repopulating controllers after attributes loaded...');
      log.d('   _selectedValues: $_selectedValues');
      log.d('   _attributes count: ${_attributes.length}');

      // НЕ очищаем контроллеры! Просто обновляем их текст
      // Потому что они уже используются в UI через putIfAbsent

      for (final attr in _attributes) {
        if (_selectedValues.containsKey(attr.id)) {
          final value = _selectedValues[attr.id];

          log.d(
            '   Updating attr ${attr.id} "${attr.title}": value=$value (styleSingle: ${attr.styleSingle})',
          );

          // CASE 1: Множество (Set) - для C1 и F типов
          if (value is Set) {
            if (value.isEmpty) {
              log.d('     ℹ️ Empty set for attr ${attr.id} - skip');
              continue;
            }

            // ✅ Для C1 (single choice) и F (multiple select) - берем первый элемент
            final firstValue = value.first.toString();
            if (_controllers.containsKey(attr.id)) {
              _controllers[attr.id]!.text = firstValue;
              log.d('     ✅ Updated Controller (from set) with "$firstValue"');
            } else {
              _controllers[attr.id] = TextEditingController(text: firstValue);
              log.d('     ✅ Created Controller (from set) with "$firstValue"');
            }
          }
          // CASE 2: Простое текстовое значение
          else if (value is String) {
            if (_controllers.containsKey(attr.id)) {
              _controllers[attr.id]!.text = value;
              log.d('     ✅ Updated text controller with "$value"');
            } else {
              _controllers[attr.id] = TextEditingController(text: value);
              log.d('     ✅ Created text controller with "$value"');
            }
          }
          // CASE 3: Диапазон (E1) - обновляем оба контроллера
          else if (value is Map &&
              (value.containsKey('min') || value.containsKey('max'))) {
            final minVal = (value['min'] ?? '').toString();
            final maxVal = (value['max'] ?? '').toString();
            final minKey = attr.id * 2;
            final maxKey = attr.id * 2 + 1;

            if (_controllers.containsKey(minKey)) {
              _controllers[minKey]!.text = minVal;
            } else {
              _controllers[minKey] = TextEditingController(text: minVal);
            }

            if (_controllers.containsKey(maxKey)) {
              _controllers[maxKey]!.text = maxVal;
            } else {
              _controllers[maxKey] = TextEditingController(text: maxVal);
            }

            log.d('     ✅ Updated range controllers: min=$minVal, max=$maxVal');
          }
          // CASE 4: Числовое значение
          else if (value is num) {
            if (_controllers.containsKey(attr.id)) {
              _controllers[attr.id]!.text = value.toString();
            } else {
              _controllers[attr.id] = TextEditingController(
                text: value.toString(),
              );
            }
            log.d('     ✅ Updated numeric controller with $value');
          }
        }
      }

      // � Установка значений по умолчанию при редактировании объявления
      if (_isEditMode) {
        // Атрибут "Вам предложат цену" (1048) - по умолчанию ВСЕГДА true
        _selectedValues[1048] = true;
        log.d(
          '   ✅ Set attribute 1048 "Вам предложат цену" to TRUE by default',
        );
      }

      // �🔔 ВАЖНО: Вызываем setState() чтобы UI пересчитался
      if (mounted) {
        setState(() {
          // Контроллеры обновлены выше, setState будет пересчитан UI
        });
      }

      log.d('✅ Controllers repopulation complete');
    } catch (e) {
      log.d('❌ Error repopulating controllers: $e');
    }
  }

  /// �📸 Загружает изображения объявления из API
  /// Скачивает каждое изображение и сохраняет локально
  Future<void> _loadAdvertImages(Map<String, dynamic> advertData) async {
    try {
      // Ищем изображения в разных возможных местах API ответа
      List<dynamic> imageUrls = [];

      if (advertData.containsKey('media') && advertData['media'] is List) {
        imageUrls = advertData['media'];
      } else if (advertData.containsKey('images') &&
          advertData['images'] is List) {
        imageUrls = advertData['images'];
      } else if (advertData.containsKey('photos') &&
          advertData['photos'] is List) {
        imageUrls = advertData['photos'];
      }

      if (imageUrls.isEmpty) {
        log.d('ℹ️ No images found in advert data');
        return;
      }

      log.d('📸 Found ${imageUrls.length} images, downloading...');

      final tempDir = await getTemporaryDirectory();
      final List<File> downloadedImages = [];

      for (int i = 0; i < imageUrls.length; i++) {
        try {
          final imageData = imageUrls[i];
          String? imageUrl;

          // Парсим URL из разных форматов
          if (imageData is String) {
            imageUrl = imageData;
          } else if (imageData is Map<String, dynamic>) {
            imageUrl =
                imageData['url'] ??
                imageData['link'] ??
                imageData['path'] ??
                imageData['image'];
          }

          if (imageUrl == null || imageUrl.isEmpty) {
            log.d('⚠️ Image $i has no URL');
            continue;
          }

          // Убедимся что URL полный
          if (!imageUrl.startsWith('http')) {
            imageUrl =
                'https://api.lidle.io' +
                (imageUrl.startsWith('/') ? '' : '/') +
                imageUrl;
          }

          // Скачиваем изображение
          log.d('  ↓ Downloading image $i: $imageUrl');
          final response = await http
              .get(Uri.parse(imageUrl))
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  log.d('  ⏱️ Timeout downloading image $i');
                  throw TimeoutException('Timeout loading image $i');
                },
              );

          if (response.statusCode == 200) {
            // Сохраняем в временную директорию
            final fileName =
                'advert_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
            final file = File('${tempDir.path}/$fileName');
            await file.writeAsBytes(response.bodyBytes);

            downloadedImages.add(file);
            log.d('  ✅ Saved image $i: $fileName');
          } else {
            log.d('  ❌ Failed to download image $i: ${response.statusCode}');
          }
        } catch (e) {
          log.d('  ❌ Error downloading image $i: $e');
          // Продолжаем загружать остальные изображения
          continue;
        }
      }

      if (downloadedImages.isNotEmpty && mounted) {
        setState(() {
          _images.addAll(downloadedImages);
        });
        log.d(
          '✅ Images loaded successfully: ${downloadedImages.length}/${imageUrls.length}',
        );
      }
    } catch (e) {
      log.d('❌ Error loading advert images: $e');
    }
  }

  /// 📞 Заполняет контактные поля из объявления
  /// Берет контакты из объявления (не из профиля пользователя)
  /// Это важно для редактирования - показать исходные контакты, а не текущие
  void _populateContactsFromAdvert(Map<String, dynamic> advertData) {
    try {
      // Заполняем телефон
      if (advertData.containsKey('phone') && advertData['phone'] != null) {
        final phone = advertData['phone'].toString();
        if (phone.isNotEmpty) {
          _phone1Controller.text = phone;
          log.d('✅ Filled phone: $phone');
        }
      }

      // Заполняем email
      if (advertData.containsKey('email') && advertData['email'] != null) {
        final email = advertData['email'].toString();
        if (email.isNotEmpty) {
          _emailController.text = email;
          log.d('✅ Filled email: $email');
        }
      }

      // Заполняем telegram
      if (advertData.containsKey('telegram') &&
          advertData['telegram'] != null) {
        final telegram = advertData['telegram'].toString();
        if (telegram.isNotEmpty) {
          _telegramController.text = telegram;
          log.d('✅ Filled telegram: $telegram');
        }
      }

      // Заполняем whatsapp
      if (advertData.containsKey('whatsapp') &&
          advertData['whatsapp'] != null) {
        final whatsapp = advertData['whatsapp'].toString();
        if (whatsapp.isNotEmpty) {
          _whatsappController.text = whatsapp;
          log.d('✅ Filled whatsapp: $whatsapp');
        }
      }

      log.d('✅ Contacts population complete');
    } catch (e) {
      log.d('❌ Error populating contacts: $e');
    }
  }

  Future<void> _loadRegions() async {
    try {
      final token = TokenService.currentToken;

      // Если нет токена, регионы все равно можно загрузить (API поддерживает без токена)
      // но если есть токен, используем его
      // Логируем для отладки
      if (token == null) {
        log.d('ℹ️ _loadRegions: Токен не найден, загружаем без токена');
      }

      final regions = await ApiService.getRegions(token: token);

      // Логируем все регионы с их ID
      log.d('📍 Загруженные регионы:');
      for (final region in regions) {
        final regionId = region['id'];
        final regionName = region['name'];
        log.d('   ID $regionId: $regionName');
      }

      if (mounted) {
        setState(() {
          _regions = regions;
        });
      }
      log.d('✅ Loaded ${regions.length} regions');
    } catch (e) {
      log.d('❌ Error loading regions: $e');
      // Retry after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadRegions();
      });
    }
  }

  Future<void> _loadCategoryInfo() async {
    try {
      if (widget.categoryId == null) {
        // log.d('⚠️ Category ID is null, using default name');
        if (mounted) {
          setState(() {
            _categoryName = 'Долгосрочная аренда комнат';
          });
        }
        return;
      }

      final token = TokenService.currentToken;
      // log.d('📦 Loading category info for ID: ${widget.categoryId}');

      // Get category info by ID
      final category = await ApiService.getCategory(
        widget.categoryId!,
        token: token,
      );

      if (mounted) {
        setState(() {
          _categoryName = category.name;
        });
      }
      // log.d('✅ Category name loaded: $_categoryName');
    } catch (e) {
      // log.d('❌ Error loading category info: $e');
      if (mounted) {
        setState(() {
          _categoryName = 'Категория';
        });
      }
    }
  }

  Future<void> _loadUserContacts() async {
    try {
      final token = TokenService.currentToken;
      // log.d('📱 Token obtained, loading user contacts...');
      if (token == null) {
        // log.d('❌ Token is null, cannot load contacts');
        return;
      }

      // Load phones - REQUIRED for publishing
      try {
        // log.d('📞 Loading phones from /me/settings/phones...');
        final phonesResponse = await ApiService.get(
          '/me/settings/phones',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (phonesResponse['data'] is List) {
          _userPhones = List<Map<String, dynamic>>.from(phonesResponse['data']);
          // log.d('✅ Loaded phones: ${_userPhones.length} phone(s)');
        } else {
          // log.d('⚠️ Phones response format incorrect');
        }
      } catch (e) {
        // log.d('❌ Error loading phones: $e');
      }

      // Load emails
      try {
        // log.d('📧 Loading emails from /me/settings/emails...');
        final emailsResponse = await ApiService.get(
          '/me/settings/emails',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (emailsResponse['data'] is List) {
          _userEmails = List<Map<String, dynamic>>.from(emailsResponse['data']);
          // log.d('✅ Loaded emails: ${_userEmails.length} email(s)');
        } else {
          // log.d('⚠️ Emails response format incorrect');
        }
      } catch (e) {
        // log.d('❌ Error loading emails: $e');
      }

      // Load telegrams
      try {
        // log.d('💬 Loading telegrams from /me/settings/telegrams...');
        final telegramsResponse = await ApiService.get(
          '/me/settings/telegrams',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (telegramsResponse['data'] is List) {
          _userTelegrams = List<Map<String, dynamic>>.from(
            telegramsResponse['data'],
          );
          // log.d('✅ Loaded telegrams: ${_userTelegrams.length} telegram(s)');
        } else {
          // log.d('⚠️ Telegrams response format incorrect');
        }
      } catch (e) {
        // log.d('❌ Error loading telegrams: $e');
      }

      // Load whatsapps
      try {
        // log.d('💬 Loading whatsapps from /me/settings/whatsapps...');
        final whatsappsResponse = await ApiService.get(
          '/me/settings/whatsapps',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (whatsappsResponse['data'] is List) {
          _userWhatsapps = List<Map<String, dynamic>>.from(
            whatsappsResponse['data'],
          );
          // log.d('✅ Loaded whatsapps: ${_userWhatsapps.length} whatsapp(s)');
        } else {
          // log.d('⚠️ Whatsapps response format incorrect');
        }
      } catch (e) {
        // log.d('❌ Error loading whatsapps: $e');
      }

      // Load user profile to get name
      try {
        // log.d('👤 Loading user profile from /me...');
        final userProfile = await UserService.getProfile(token: token);
        // log.d();

        // Fill user profile data into controllers
        if (mounted) {
          setState(() {
            // 📝 Парсим полное имя на отдельные части - в поле только имя
            final fullName = '${userProfile.name} ${userProfile.lastName}'
                .trim();
            final nameParts = fullName.split(RegExp(r'\s+'));
            final firstName = nameParts.isNotEmpty ? nameParts.first : '';
            _contactNameController.text = firstName;
            // log.d('✅ Filled contact name (first name only): $firstName');

            // Fill email from first available email
            if (_userEmails.isNotEmpty) {
              final email = _userEmails[0]['email'] ?? '';
              _emailController.text = email;
              // log.d('✅ Filled email: $email');
            }

            // Fill phone1 from first available phone
            if (_userPhones.isNotEmpty) {
              final phone = _userPhones[0]['phone'] ?? '';
              _phone1Controller.text = phone;
              // log.d('✅ Filled phone1: $phone');
            }
          });
        }
      } catch (e) {
        // log.d('⚠️ Error loading user profile: $e');
      }

      if (mounted) {
        setState(() {});
      }
      // log.d('✅ User contacts loading complete');
    } catch (e) {
      // log.d('❌ Error loading user contacts: $e');
      // log.d('   Stack trace: ${StackTrace.current}');
    }
  }

  // 🧪 ТЕСТОВОЕ АВТОЗАПОЛНЕНИЕ ФОРМЫ (ОТКЛЮЧЕНО)
  // Автозаполнение было нужно для тестирования, теперь отключено
  void _autoFillFormForTesting() {
    if (!mounted) return;

    // Автозаполнение отключено - все поля оставляем пустыми
    // Пользователь должен заполнить форму вручную

    // Только инициализируем обязательный атрибут "Вам предложат цену" значением true
    // Но только если этот атрибут существует в этой категории
    final offerPriceAttrId = _getOfferPriceAttributeId();
    if (offerPriceAttrId != null &&
        _attributes.any((a) => a.id == offerPriceAttrId)) {
      _selectedValues[offerPriceAttrId] = true;
      // log.d('🧪 Auto-fill DISABLED - user must fill form manually');
      // log.d('   Only initialized required attribute $offerPriceAttrId = true');
    } else {
      // log.d('🧪 Auto-fill DISABLED - could not find offer price attribute');
    }
  }

  /// Загружает города для выбранного региона при автозаполнении
  // ignore: unused_element
  /// 🆕 Поиск городов через API по пользовательскому вводу (для диалога)
  /// Вызывается из CitySelectionDialog когда пользователь вводит текст
  Future<List<String>> _searchCitiesAPI(String query) async {
    if (_selectedRegionId == null) {
      log.d('🔍 _searchCitiesAPI: regionId not selected');
      return [];
    }

    // Проверяем минимальную длину (API требует >= 3)
    if (query.trim().length < 3) {
      log.d('🔍 _searchCitiesAPI: query too short: "$query" (need 3+)');
      return [];
    }

    try {
      final token = TokenService.currentToken;
      final cleanQuery = query.trim();

      log.d('');
      log.d('🔍 _searchCitiesAPI called:');
      log.d('   - query: "$cleanQuery"');
      log.d('   - regionId: $_selectedRegionId');

      final response = await AddressService.searchAddresses(
        query: cleanQuery,
        token: token,
        types: ['city'],
        filters: {'main_region_id': _selectedRegionId},
      );

      log.d('   - API вернула ${response.data.length} результатов');

      // 🆕 Очищаем предыдущие результаты и сохраняем новые
      _lastCitiesSearchResults.clear();

      // Фильтруем результаты по выбранному региону и извлекаем только имена
      final cities = <String>[];
      int filtered = 0;

      for (final result in response.data) {
        final cityName = result.city?.name ?? 'N/A';
        final cityId = result.city?.id;
        final resultRegionId = result.main_region?.id;

        log.d(
          '   [API] $cityName [id=$cityId, main_region.id=$resultRegionId]',
        );

        if (result.main_region?.id == _selectedRegionId &&
            result.city != null) {
          final cityName = result.city!.name;
          // Сохраняем в кеш всегда (нужно для ID lookup)
          _lastCitiesSearchResults[cityName] = result.city!.id;
          // В список показа добавляем только если имя содержит запрос
          if (cityName.toLowerCase().contains(cleanQuery.toLowerCase())) {
            cities.add(cityName);
            log.d('       ✅ СОХРАНЕНО в кеш и список');
          } else {
            log.d('       📦 СОХРАНЕНО в кеш (не совпало с запросом)');
          }
        } else {
          filtered++;
          if (result.main_region?.id != _selectedRegionId) {
            log.d(
              '       ❌ Фильтр: main_region.id=$resultRegionId != $_selectedRegionId',
            );
          } else {
            log.d('       ❌ Фильтр: city is null');
          }
        }
      }

      log.d(
        '   ✅ Возвращаем ${cities.length} городов (отфильтровано: $filtered)',
      );
      log.d('   📦 Cache содержит: ${_lastCitiesSearchResults.keys.toList()}');
      log.d('');
      return cities;
    } catch (e) {
      log.d('   ❌ Error searching cities: $e');
      return [];
    }
  }

  /// 🆕 Поиск улиц через API по пользовательскому вводу (для диалога)
  /// Вызывается из StreetSelectionDialog когда пользователь вводит текст
  Future<List<String>> _searchStreetsAPI(String query) async {
    if (_selectedCityId == null) {
      log.d('🔍 _searchStreetsAPI: cityId not selected');
      return [];
    }

    // Проверяем минимальную длину (API требует >= 3)
    if (query.trim().length < 3) {
      log.d('🔍 _searchStreetsAPI: query too short: "$query" (need 3+)');
      return [];
    }

    try {
      final token = TokenService.currentToken;
      final cleanQuery = query.trim();

      log.d('');
      log.d('🔍 _searchStreetsAPI called:');
      log.d('   - query: "$cleanQuery"');
      log.d('   - cityId: $_selectedCityId');

      final response = await AddressService.searchAddresses(
        query: cleanQuery,
        token: token,
        types: ['street'],
        filters: {'city_id': _selectedCityId},
      );

      log.d('   - API вернула ${response.data.length} результатов');

      // 🆕 Очищаем предыдущие результаты и сохраняем новые
      _lastStreetsSearchResults.clear();

      // Фильтруем результаты по выбранному городу и извлекаем только имена
      final streets = <String>[];
      int filtered = 0;

      for (final result in response.data) {
        final streetName = result.street?.name ?? 'N/A';
        final streetId = result.street?.id;
        final resultCityId = result.city?.id;

        log.d('   [API] $streetName [id=$streetId, city.id=$resultCityId]');

        if (result.city?.id == _selectedCityId && result.street != null) {
          streets.add(result.street!.name);
          // 🆕 Сохраняем mapping имя улицы -> ID
          _lastStreetsSearchResults[result.street!.name] = result.street!.id;
          // 🆕 Сохраняем subregion ID
          _lastStreetsSubregionResults[result.street!.name] = result.region?.id;
          log.d(
            '       ✅ СОХРАНЕНО в кеш (street.id=${result.street!.id}, region.id=${result.region?.id})',
          );
        } else {
          filtered++;
          if (result.city?.id != _selectedCityId) {
            log.d('       ❌ Фильтр: city.id=$resultCityId != $_selectedCityId');
          } else {
            log.d('       ❌ Фильтр: street is null');
          }
        }
      }

      log.d(
        '   ✅ Возвращаем ${streets.length} улиц (отфильтровано: $filtered)',
      );
      log.d('   📦 Cache содержит: ${_lastStreetsSearchResults.keys.toList()}');
      log.d('');
      return streets;
    } catch (e) {
      log.d('   ❌ Error searching streets: $e');
      return [];
    }
  }

  Future<void> _loadCitiesForSelectedRegion() async {
    if (_selectedRegionId == null) return;

    try {
      final token = TokenService.currentToken;
      String searchQuery = 'по'; // Default search term

      if (_selectedRegion.isNotEmpty) {
        final regionName = _selectedRegion.first;
        if (regionName.length >= 3) {
          searchQuery = regionName.length > 50
              ? regionName.substring(0, 50)
              : regionName;
        } else {
          searchQuery = regionName + '   '; // Pad to at least 3
        }
      }

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['city'],
        filters: _selectedRegionId != null
            ? {'main_region_id': _selectedRegionId}
            : null,
      );

      log.d(
        '🔍 [AUTO] Загрузка для области ID: $_selectedRegionId, query: "$searchQuery"',
      );
      log.d('📋 [AUTO] API вернул ${response.data.length} результатов');

      final uniqueCities = <String, int>{};
      int filtered = 0;
      for (final result in response.data) {
        if (result.main_region?.id == _selectedRegionId &&
            result.city != null) {
          uniqueCities[result.city!.name] = result.city!.id;
          _lastCitiesSearchResults[result.city!.name] =
              result.city!.id; // ← ДОБАВИТЬ
          log.d('   ✅ ${result.city!.name}');
        } else if (result.city != null) {
          filtered++;
          log.d(
            '   ❌ ${result.city!.name} - main_region.id=${result.main_region?.id}, ожидаем $_selectedRegionId',
          );
        }
      }

      if (mounted) {
        setState(() {
          _cities = uniqueCities.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
          // Сортируем для удобства
          _cities.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
        });
        log.d('✅ Auto-loaded ${_cities.length} cities');
      }
    } catch (e) {
      log.d('❌ Error auto-loading cities: $e');
    }
  }

  /// Загружает улицы для выбранного города при автозаполнении
  // ignore: unused_element
  Future<void> _loadStreetsForSelectedCity() async {
    if (_selectedCityId == null) return;

    try {
      final token = TokenService.currentToken;
      String searchQuery = 'у';

      if (_selectedCity.isNotEmpty) {
        final cityName = _selectedCity.first;
        if (cityName.length >= 3) {
          searchQuery = cityName.length > 50
              ? cityName.substring(0, 50)
              : cityName;
        } else {
          searchQuery = cityName + '   ';
        }
      }

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['street'],
        filters: _selectedCityId != null ? {'city_id': _selectedCityId} : null,
      );

      final uniqueStreets = <String, int>{};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          uniqueStreets[result.street!.name] = result.street!.id;
          log.d('   + ${result.street!.name}');
        } else if (result.street != null) {
          log.d(
            '   ❌ ${result.street!.name} - city.id=${result.city?.id}, ожидаем $_selectedCityId',
          );
        }
      }

      if (mounted) {
        setState(() {
          _streets = uniqueStreets.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
        log.d('✅ Auto-loaded ${_streets.length} streets');
      }
    } catch (e) {
      log.d('❌ Error auto-loading streets: $e');
    }
  }

  /// Загружает номера домов для выбранной улицы
  Future<void> _loadBuildingsForSelectedStreet() async {
    if (_selectedStreetId == null) return;

    try {
      final token = TokenService.currentToken;
      String searchQuery = '1'; // Default search term

      if (_selectedStreet.isNotEmpty) {
        final streetName = _selectedStreet.first;
        if (streetName.length >= 3) {
          searchQuery = streetName.length > 50
              ? streetName.substring(0, 50)
              : streetName;
        } else {
          searchQuery = streetName + '   ';
        }
      }

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['building'],
        filters: _selectedStreetId != null
            ? {'street_id': _selectedStreetId}
            : null,
      );

      final uniqueBuildings = <String, int>{};
      for (final result in response.data) {
        if (result.street?.id == _selectedStreetId && result.building != null) {
          uniqueBuildings[result.building!.name] = result.building!.id;
          log.d('   + ${result.building!.name}');
        } else if (result.building != null) {
          log.d(
            '   ❌ ${result.building!.name} - street.id=${result.street?.id}, ожидаем $_selectedStreetId',
          );
        }
      }

      if (mounted) {
        setState(() {
          _buildings = uniqueBuildings.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
        log.d('✅ Auto-loaded ${_buildings.length} buildings');
      }
    } catch (e) {
      log.d('❌ Error auto-loading buildings: $e');
    }
  }

  int? mainRegionId = 1; // Track main_region.id for top-level region_id
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  /// Снимает одну фотографию с камеры
  Future<void> _pickImageFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
        _fieldErrors.remove('images');
      });
    }
  }

  /// Выбирает несколько фотографий из галереи
  Future<void> _pickMultipleImagesFromGallery() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        // Добавляем выбранные фотографии в список
        for (final pickedFile in pickedFiles) {
          _images.add(File(pickedFile.path));
        }
        _fieldErrors.remove('images');
      });
      if (mounted) {
        // log.d();
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232E3C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 13.0),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SvgPicture.asset(
                        'assets/showImageSourceActionSheet/camera-01.svg',
                      ),
                      title: const Text(
                        'Сделать фотографию',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        _pickImageFromCamera();
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SvgPicture.asset(
                        'assets/showImageSourceActionSheet/image-01.svg',
                      ),
                      title: const Text(
                        'Загрузить несколько фотографий',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickMultipleImagesFromGallery();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  bool? isIndividualSelected =
      null; // null = not selected, true = Частное лицо, false = Бизнес
  bool isSecondarySelected = true;
  bool isMortgageYes = true;

  bool isBargain = false;
  bool isNoCommission = false;
  bool isExchange = false;
  bool isPledge = false;
  bool isUrgent = false;
  bool isInstallment = false;
  bool isRemoteDeal = false;
  bool isClientPrice = false;
  bool isAutoRenewal = false;
  bool isAutoRenewal1 = false;

  String _selectedAction = 'publish';

  // ignore: unused_element
  void _togglePersonType(bool isIndividual) {
    setState(() {
      isIndividualSelected = isIndividual;
      // Dynamically get seller type attribute ID instead of hardcoding 19
      final sellerTypeAttrId = _attributeResolver.getSellerTypeAttributeId();
      if (sellerTypeAttrId != null) {
        _selectedValues[sellerTypeAttrId] = isIndividual
            ? 'Частное лицо'
            : 'Бизнес';
        // log.d();
      } else {
        // log.d('⚠️ Seller type attribute ID not found in category');
      }
    });
  }

  CreateAdvertRequest _collectFormData() {
    // Collect attributes
    final Map<String, dynamic> attributes = {
      'value_selected': <int>[],
      'values': <String, dynamic>{},
    };

    // 🔍 ДИАГНОСТИКА: Начало сбора атрибутов
    log.d('');
    log.d('═══════════════════════════════════════════════════════');
    log.d('🔍 ДИАГНОСТИКА: _collectFormData() Начало');
    log.d('═══════════════════════════════════════════════════════');
    log.d('📋 Загруженные атрибуты в _attributes:');
    for (final attr in _attributes) {
      log.d(
        '   - ID ${attr.id}: "${attr.title}" (is_multiple=${attr.isMultiple}, values=${attr.values.length})',
      );
    }
    log.d('');
    log.d('📂 Значения в _selectedValues (к обработке):');
    _selectedValues.forEach((k, v) {
      log.d('   - Key=$k: $v (Type: ${v.runtimeType})');
    });
    log.d('');

    _selectedValues.forEach((key, value) {
      // CRITICAL FIX: Skip attributes that don't exist in the loaded category
      // This prevents "Attribute does not belong to category" errors
      final attr = _attributes.firstWhere(
        (a) => a.id == key,
        orElse: () => Attribute(id: 0, title: '', order: 0, values: []),
      );
      if (attr.id == 0) {
        // log.d('⚠️ WARNING: Filter ID $key not found in loaded attributes! SKIPPING.');
        return; // Skip this attribute - it doesn't exist in this category
      }

      if (value is Set<String>) {
        // Multiple selection - but check if attribute allows multiple values
        // Some attributes like "Количество комнат" (ID=6) have is_multiple=false
        // These should only send ONE value to the API
        if (attr.isMultiple) {
          // API allows multiple - add all selected values
          // log.d();
          for (final val in value) {
            final attrValue = attr.values.firstWhere(
              (v) => v.value == val,
              orElse: () => const Value(id: 0, value: ''),
            );
            if (attrValue.id != 0) {
              // log.d();
              attributes['value_selected'].add(attrValue.id);
            }
          }
        } else {
          // API allows only one value - take first
          // log.d();
          if (value.isNotEmpty) {
            final firstVal = value.first;
            final attrValue = attr.values.firstWhere(
              (v) => v.value == firstVal,
              orElse: () => const Value(id: 0, value: ''),
            );
            if (attrValue.id != 0) {
              // log.d('   ✅ Adding single value: $firstVal (ID=${attrValue.id})');
              attributes['value_selected'].add(attrValue.id);
            } else {
              // log.d('   ❌ Value "$firstVal" not found in attribute values');
            }
          } else {
            // log.d('   ⚠️ No values selected for is_multiple=false attribute');
          }
        }

        // SPECIAL DIAGNOSTIC: Log attribute 6 handling
        if (key == 6) {
          // log.d('🔍🔍 SPECIAL DIAGNOSTIC FOR ATTRIBUTE 6 (ROOMS):');
          // log.d('   is_multiple: ${attr.isMultiple}');
          // log.d('   Selected values in Set: $value');
          // log.d('   Number of values: ${value.length}');
          // log.d('   All available values for attr 6:');
          for (final _ in attr.values) {
            // log.d('      - "${_.value}" (ID=${_.id})');
          }
          if (value.isNotEmpty) {
            // debug: value contains selected values
          }
        }
      } else if (value is Map) {
        // Range values - for attributes like 1040 (floor) - but NOT 1127 anymore
        final minVal = (value['min']?.toString() ?? '').trim();
        final maxVal = (value['max']?.toString() ?? '').trim();
        // log.d();

        // Parse values based on data type
        dynamic parsedValue;
        dynamic parsedMaxValue;
        if (minVal.isNotEmpty) {
          if (attr.dataType == 'integer') {
            parsedValue = int.tryParse(minVal);
          } else if (attr.dataType == 'numeric') {
            parsedValue = double.tryParse(minVal);
          } else {
            parsedValue = minVal;
          }
        }
        if (maxVal.isNotEmpty) {
          if (attr.dataType == 'integer') {
            parsedMaxValue = int.tryParse(maxVal);
          } else if (attr.dataType == 'numeric') {
            parsedMaxValue = double.tryParse(maxVal);
          } else {
            parsedMaxValue = maxVal;
          }
        }

        // Build object for range attribute
        final attrObj = {};
        if (parsedValue != null) {
          attrObj['value'] = parsedValue;
        }
        if (parsedMaxValue != null) {
          attrObj['max_value'] = parsedMaxValue;
        }
        if (attrObj.isNotEmpty) {
          attributes['values']['$key'] = attrObj;
          // log.d('   Added range attr $key: $attrObj');
        }
      } else if (value is String) {
        if (attr.values.isEmpty) {
          // Text field - DO NOT add to attributes.values (API doesn't accept them)
          if (value.isNotEmpty) {
            // log.d();
          }
        } else {
          // Single selection - lookup value ID
          final attrValue = attr.values.firstWhere(
            (v) => v.value == value,
            orElse: () => const Value(id: 0, value: ''),
          );
          if (attrValue.id != 0) {
            attributes['value_selected'].add(attrValue.id);
            // log.d();
          }
        }
      } else if (value is bool && value) {
        // Checkbox or boolean value
        // Attribute 1048 (Вам предложат цену) is a boolean type with no values array
        // DO NOT add to value_selected - will be handled separately below
        // (value_selected should only contain VALUE IDs from options)
        if (key != 1048 && attr.values.isNotEmpty) {
          attributes['value_selected'].add(attr.values.first.id);
        }
      }
    });

    // Ensure attribute 1048 (Вам предложат цену) is set if not already
    // This will be handled above in the value_selected block
    // No need to add as separate field anymore

    // DIAGNOSTIC: Map value_ids back to attributes
    // log.d('🔧 DIAGNOSTIC - Mapping value_ids to attributes:');
    for (final valueId in attributes['value_selected'] as List<int>) {
      String? foundAttrTitle = 'UNKNOWN';
      for (final attr in _attributes) {
        final matchingValue = attr.values.firstWhere(
          (v) => v.id == valueId,
          orElse: () => const Value(id: 0, value: ''),
        );
        if (matchingValue.id != 0) {
          foundAttrTitle = '${attr.id}:${attr.title}';
          // log.d();
          break;
        }
      }
      if (foundAttrTitle == 'UNKNOWN') {
        // log.d();
      }
    }
    // log.d('Collected attributes: $attributes');

    // Handle "Вам предложат цену" attribute (ID varies by category)
    // IMPORTANT: This should be in attributes.values, NOT in value_selected!
    // API expects: attributes.values['{id}'] = {'value': 1}
    // ⚠️ КРИТИЧНО: Отправляем только если атрибут существует в этой категории!
    final offerPriceAttrId = _getOfferPriceAttributeId();

    if (offerPriceAttrId != null &&
        _attributes.any((a) => a.id == offerPriceAttrId)) {
      // Атрибут существует в этой категории - добавляем в запрос
      if (_selectedValues.containsKey(offerPriceAttrId) &&
          _selectedValues[offerPriceAttrId] == true) {
        attributes['values']['$offerPriceAttrId'] = {'value': 1};
        // log.d();
      } else {
        // If not explicitly selected, add by default (it's required)
        attributes['values']['$offerPriceAttrId'] = {'value': 1};
        // log.d();
      }
    } else {
      // log.d();
    }

    // Handle required attribute "Общая площадь" (Total area) - ID varies by category
    // ⚠️ КРИТИЧНО: Отправляем только если атрибут существует в этой категории!
    final areaAttrId = _attributeResolver.getAreaAttributeId();

    if (areaAttrId != null && _attributes.any((a) => a.id == areaAttrId)) {
      // Атрибут существует в этой категории - добавляем в запрос
      if (_selectedValues.containsKey(areaAttrId)) {
        final area = _selectedValues[areaAttrId];
        if (area is String && area.isNotEmpty) {
          final areaVal = int.tryParse(area.toString().trim());
          if (areaVal != null) {
            attributes['values']['$areaAttrId'] = {'value': areaVal};
            // log.d('✅ Attribute $areaAttrId (area) set: value=$areaVal');
          } else {
            // If parsing fails, set default - но только если атрибут обязательный!
            final areaAttr = _attributeResolver.getAttributeById(areaAttrId);
            if (areaAttr != null && areaAttr.isRequired) {
              attributes['values']['$areaAttrId'] = {'value': 50};
              // log.d('⚠️ Failed to parse area value, using default: 50');
            } else {
              // log.d();
            }
          }
        } else {
          // Set default area if not selected - но только если атрибут обязательный!
          final areaAttr = _attributeResolver.getAttributeById(areaAttrId);
          if (areaAttr != null && areaAttr.isRequired) {
            attributes['values']['$areaAttrId'] = {'value': 50};
            // log.d('✅ Set default $areaAttrId: value=50');
          } else {
            // log.d();
          }
        }
      } else {
        // Атрибут заполнен? Нет - проверяем обязателен ли
        final areaAttr = _attributeResolver.getAttributeById(areaAttrId);
        if (areaAttr != null && areaAttr.isRequired) {
          // Обязательный - добавляем дефолт
          attributes['values']['$areaAttrId'] = {'value': 50};
          // log.d('✅ Set required default $areaAttrId: value=50');
        } else {
          // Не обязательный - не добавляем
          // log.d();
        }
      }
    } else {
      // log.d();
    }

    // NOTE: attribute_1048 (boolean type) is handled separately via toJson() in CreateAdvertRequest
    // It's extracted to top-level and NOT added to value_selected
    // (value_selected should only contain VALUE IDs, not attribute IDs)

    // Collect address
    // NOTE: address will be updated via searchAddresses() in _publishAdvert()
    // This just collects whatever UI values exist
    final Map<String, dynamic> address = {};

    // log.d('Collected address: $address');

    // Collect contacts with proper validation
    // According to API docs: user_phone_id is REQUIRED, user_email_id may be required
    final Map<String, dynamic> contacts = {};

    // Primary phone is required
    if (_userPhones.isNotEmpty) {
      contacts['user_phone_id'] = _userPhones.first['id'];
      // log.d('✅ Using phone ID: ${_userPhones.first['id']} (${_userPhones.first['phone']})');
    }

    // Email handling - ALWAYS include email ID if available
    // API requires email - error message says: "contacts.user_email_id: обязательно для заполнения"
    // This means email is REQUIRED, regardless of verification status
    if (_userEmails.isNotEmpty) {
      final emailData = _userEmails.first;
      final isVerified = emailData['email_verified_at'] != null;

      contacts['user_email_id'] = emailData['id'];
      if (isVerified) {
        // log.d('✅ Using verified email ID: ${emailData['id']} (${emailData['email']})');
      } else {
        // log.d('⚠️ Email NOT verified (email_verified_at=null): ${emailData['email']} - but API requires it, sending anyway');
      }
    } else {
      // log.d('❌ ERROR: No email contacts found!');
    }

    if (_userTelegrams.isNotEmpty) {
      contacts['user_telegram_id'] = _userTelegrams.first['id'];
    }
    if (_userWhatsapps.isNotEmpty) {
      contacts['user_whatsapp_id'] = _userWhatsapps.first['id'];
    }

    // log.d('Collected contacts: $contacts');

    // 🔍 ДИАГНОСТИКА: Результат сбора атрибутов
    log.d('');
    log.d('✅ Собранные атрибуты для отправки:');
    log.d('   value_selected: ${attributes['value_selected']}');
    log.d('   values: ${attributes['values']}');
    log.d('═══════════════════════════════════════════════════════');
    log.d('');

    return CreateAdvertRequest(
      name: _titleController.text,
      description: _descriptionController.text,
      price: _priceController.text,
      categoryId: _editAdvertCategoryId ?? widget.categoryId ?? 2,
      regionId:
          mainRegionId ??
          1, // Use mainRegionId (top-level region), not address.region_id
      address: address,
      attributes: attributes,
      contacts: contacts,
      isAutoRenew: isAutoRenewal,
    );
  }

  /// Scrolls to top of form to show validation errors
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Validates all required fields and populates _fieldErrors map
  /// Returns true if all validations pass, false otherwise
  bool _validateForm() {
    // Clear previous errors
    _fieldErrors.clear();

    // Validate images
    if (_images.isEmpty) {
      _fieldErrors['images'] = 'Добавьте хотя бы одно изображение';
    }

    // Validate required text fields
    if (_titleController.text.isEmpty) {
      _fieldErrors['title'] = 'Заполните заголовок объявления';
    } else if (_titleController.text.length < 16) {
      _fieldErrors['title'] = 'Введите не менее 16 символов';
    }

    if (_descriptionController.text.isEmpty) {
      _fieldErrors['description'] = 'Заполните описание';
    } else if (_descriptionController.text.length < 70) {
      _fieldErrors['description'] = 'Введите не менее 70 символов';
    }

    if (_priceController.text.isEmpty) {
      _fieldErrors['price'] = 'Заполните цену';
    }

    if (_contactNameController.text.isEmpty) {
      _fieldErrors['contactName'] = 'Заполните контактное лицо';
    }

    if (_phone1Controller.text.isEmpty) {
      _fieldErrors['phone1'] = 'Заполните номер телефона';
    }

    // Validate required address fields
    if (_selectedRegion.isEmpty) {
      _fieldErrors['region'] = 'Выберите область';
    }

    if (_selectedCity.isEmpty) {
      _fieldErrors['city'] = 'Выберите город';
    }

    if (_selectedStreet.isEmpty) {
      _fieldErrors['street'] = 'Выберите улицу';
    }

    // Validate required attributes from API
    for (final attr in _attributes) {
      if (attr.isRequired) {
        final value = _selectedValues[attr.id];
        if (value == null) {
          _fieldErrors['attr_${attr.id}'] = 'Заполните поле "${attr.title}"';
        } else if (value is String && value.isEmpty) {
          _fieldErrors['attr_${attr.id}'] = 'Заполните поле "${attr.title}"';
        } else if (value is Map) {
          final minVal = (value['min']?.toString() ?? '').trim();
          final maxVal = (value['max']?.toString() ?? '').trim();
          if (minVal.isEmpty && maxVal.isEmpty) {
            _fieldErrors['attr_${attr.id}'] = 'Заполните поле "${attr.title}"';
          }
        } else if (value is Set<String> && value.isEmpty) {
          _fieldErrors['attr_${attr.id}'] = 'Заполните поле "${attr.title}"';
        }
      }
    }

    // Validate special attribute: "Вам предложат цену" (ID varies by category)
    final offerPriceAttrId = _getOfferPriceAttributeId();
    if (offerPriceAttrId != null) {
      if (!_selectedValues.containsKey(offerPriceAttrId) ||
          _selectedValues[offerPriceAttrId] != true) {
        _fieldErrors['offerPrice'] =
            'Необходимо согласиться принимать предложения по цене';
      }
    }

    return _fieldErrors.isEmpty;
  }

  Future<void> _publishAdvert() async {
    try {
      // Validate all fields
      if (!_validateForm()) {
        // Update UI to show validation errors
        setState(() {});
        // Scroll to top to see errors
        _scrollToTop();
        return;
      }

      // Validate user phones
      if (_userPhones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Необходимо добавить телефон в настройках профиля',
            ),
            action: SnackBarAction(
              label: 'Настройки',
              onPressed: () {
                // TODO: Перейти в настройки профиля
                // Navigator.pushNamed(context, '/profile-settings');
              },
            ),
          ),
        );
        return;
      }

      var request = _collectFormData();

      // Search for address to get correct IDs from API
      var address = <String, dynamic>{};

      // ENSURE city and street are selected
      if (_selectedCity.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, выберите город')),
        );
        setState(() => _isPublishing = false);
        return;
      }

      if (_selectedStreet.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, выберите улицу')),
        );
        setState(() => _isPublishing = false);
        return;
      }

      if (_selectedCity.isNotEmpty && _selectedStreet.isNotEmpty) {
        try {
          final token = TokenService.currentToken;
          if (token != null) {
            // log.d('🔍 Starting 3-step address search...');

            // ============ STEP 1: Search for city WITHOUT filters ============
            // ============ Prepare address from selected API data ============
            // Use already loaded IDs from API searches during dropdown selections
            if (_selectedRegionId == null) {
              throw Exception('Region not selected');
            }
            if (_selectedCityId == null) {
              throw Exception('City not selected');
            }
            if (_selectedStreetId == null) {
              throw Exception('Street not selected');
            }

            // 🔧 Номер дома не требуется - поле необязательное
            // Пользователь может оставить его пустым как при создании, так и при редактировании

            

            // Строим ЧИСТЫЙ адрес - только плоские ID поля
            address = <String, dynamic>{
              'city_id': _selectedCityId,
              'street_id': _selectedStreetId,
            };

            // region_id для адреса - ищем в порядке приоритета
            int? addressRegionId;

            // 1. Из кеша поиска улиц
            if (_selectedStreet.isNotEmpty) {
              addressRegionId = _lastStreetsSubregionResults[_selectedStreet.first];
            }

            // 2. Из локального списка улиц
            if (addressRegionId == null && _selectedStreet.isNotEmpty) {
              final streetIndex = _streets.indexWhere(
                (s) => s['name'] == _selectedStreet.first,
              );
              if (streetIndex >= 0) {
                addressRegionId = _streets[streetIndex]['region_id'] as int?;
                addressRegionId ??= _streets[streetIndex]['main_region_id'] as int?;
              }
            }

            // 3. Финальный fallback — выбранный пользователем регион
            addressRegionId ??= _selectedRegionId;

            if (addressRegionId != null) {
              address['region_id'] = addressRegionId;
            }
            

            // Дом: building_id если есть, иначе building_number
            String buildingNumber = '';
            if (_selectedBuilding.isNotEmpty) {
              buildingNumber = _selectedBuilding.first;
            } else if (_buildingController.text.isNotEmpty && _isEditMode) {
              // При редактировании, если _selectedBuilding пуст, получаем номер из парсинга
              // из _buildingController (который содержит полный адрес)
              final parts = _buildingController.text
                  .split(',')
                  .map((p) => p.trim())
                  .toList();
              if (parts.length >= 3) {
                buildingNumber = parts.last; // последний элемент - номер дома
              }
            }
            if (_selectedBuildingId != null) {
              address['building_id'] = _selectedBuildingId;
            } else if (buildingNumber.isNotEmpty) {
              address['building_number'] = buildingNumber;
            }

            // log.d('✅ Address prepared from selections:');
            // log.d('   region_id (for address): ${address['region_id']}');
            // log.d('   city_id: ${address['city_id']}');
            // log.d('   street_id: ${address['street_id']}');
            // log.d('   building_number: ${address['building_number']}');
            // log.d();
            // log.d('');
            // log.d('📋 DEBUG INFO - Selected values stored:');
            // log.d('   _selectedRegion: $_selectedRegion');
            // log.d('   _selectedRegionId: $_selectedRegionId');
            // log.d('   _selectedCity: $_selectedCity');
            // log.d('   _selectedCityId: $_selectedCityId');
            // log.d('   _selectedStreet: $_selectedStreet');
            // log.d('   _selectedStreetId: $_selectedStreetId');
            // log.d('   _selectedBuilding: $_selectedBuilding');
            // log.d('   _selectedBuildingId: $_selectedBuildingId');
            // log.d('');
            // log.d('📋 DEBUG INFO - Lists content:');
            // log.d('   _regions: ${_regions.map((r) => '${r['name']}(id=${r['id']})').toList()}');
            // log.d('   _cities: ${_cities.map((c) => '${c['name']}(id=${c['id']})').toList()}');
            // log.d('   _streets: ${_streets.map((s) => '${s['name']}(id=${s['id']})').toList()}');
            // log.d('   _buildings: ${_buildings.map((b) => '${b['name']}(id=${b['id']})').toList()}');

            // Recreate request with address from API selections
            if (address.isNotEmpty) {
              // Ensure 1048 is in values (not as separate attribute_1048 key)
              final updatedAttributes = Map<String, dynamic>.from(
                request.attributes,
              );

              // Make sure offer price attribute is in values with correct format {value: 1}
              // IMPORTANT: API expects {value: 1}, NOT boolean true
              final offerPriceAttrId = _attributeResolver
                  .getOfferPriceAttributeId();
              if (updatedAttributes.containsKey('attribute_1048')) {
                updatedAttributes.remove('attribute_1048');
                // log.d('   🗑️ Removed top-level attribute_1048 key');
              }
              if (updatedAttributes.containsKey('values')) {
                final values =
                    updatedAttributes['values'] as Map<String, dynamic>;
                // Remove any boolean values for offer price attributes
                if (values.containsKey('1048') && values['1048'] is! Map) {
                  values.remove('1048');
                  // log.d('   🗑️ Removed non-map 1048 from values');
                }
                if (values.containsKey('1050') && values['1050'] is! Map) {
                  values.remove('1050');
                  // log.d('   🗑️ Removed non-map 1050 from values');
                }
                // 🔧 FIX: Only set offer price attribute if it exists in this category
                // For Jobs and other categories without this attribute, offerPriceAttrId will be null
                if (offerPriceAttrId != null) {
                  values['$offerPriceAttrId'] = {'value': 1};
                  // log.d('   ✅ Set $offerPriceAttrId in values as {value: 1}');
                }
              }

              request = CreateAdvertRequest(
                name: request.name,
                description: request.description,
                price: request.price,
                categoryId: request.categoryId,
                regionId: mainRegionId ?? 1,
                address: address,
                attributes: updatedAttributes,
                contacts: request.contacts,
                isAutoRenew: request.isAutoRenew,
                images: request.images,
              );
            }
          }
        } catch (e) {
          // log.d('❌ Address search failed: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка поиска адреса: $e')));
          setState(() => _isPublishing = false);
          return;
        }
      } else {
        // log.d('⚠️ City or street not selected, address will be empty');
      }

      log.d('═══════════════════════════════════════════════════════');
      log.d('📋 АДРЕС ПЕРЕД ОТПРАВКОЙ В API (4 параметра):');
      log.d('═══════════════════════════════════════════════════════');
      log.d('   1️⃣  region: ${address['region']}');
      log.d('   2️⃣  city: ${address['city']}');
      log.d('   3️⃣  street: ${address['street']}');
      log.d('   4️⃣  building_number: ${address['building_number']}');
      log.d('');
      log.d('📊 IDs для адреса (если используются):');
      log.d('   region_id: ${address['region_id']}');
      log.d('   city_id: ${address['city_id']}');
      log.d('   street_id: ${address['street_id']}');
      log.d('═══════════════════════════════════════════════════════');

      if (request.contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимо выбрать контактные данные')),
        );
        setState(() => _isPublishing = false);
        return;
      }

      final token = TokenService.currentToken;

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимо авторизоваться')),
        );
        setState(() => _isPublishing = false);
        return;
      }

      // Show loading with progress
      setState(() {
        _isPublishing = true;
        _publishingProgress = 'Подготовка объявления...';
      });

      // Log final request before sending
      log.d('════════════════════════════════════════════════════════');
      log.d('📤 ФИНАЛЬНЫЙ ЗАПРОС В API:');
      log.d('   name: ${request.name}');
      log.d('   price: ${request.price}');
      log.d('   categoryId: ${request.categoryId}');
      log.d('   АДРЕС (address):');
      log.d('      ├─ region: ${request.address['region']}');
      log.d('      ├─ city: ${request.address['city']}');
      log.d('      ├─ street: ${request.address['street']}');
      log.d('      └─ building_number: ${request.address['building_number']}');
      log.d(
        '   attributes.value_selected: ${request.attributes['value_selected']}',
      );
      log.d(
        '   attributes.values keys: ${request.attributes['values'].keys.toList()}',
      );
      log.d('================================================================');

      // VERIFY address has city_id (region_id is optional subregion)
      if (!request.address.containsKey('city_id') ||
          request.address['city_id'] == null) {
        // log.d('❌ ERROR: city_id is missing or null in address!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ошибка: город не найден. Пожалуйста, выберите другой адрес',
            ),
          ),
        );
        setState(() => _isPublishing = false);
        return;
      }

      // Step 1: Create or update advert WITHOUT images first
      setState(() {
        _publishingProgress = _isEditMode
            ? 'Обновление объявления...'
            : 'Отправка объявления на модерацию...';
      });

      // 🔍 ДИАГНОСТИКА: Выводим что будет отправлено на API
      log.d('═══════════════════════════════════════════════════════');
      log.d('📤 ДИАГНОСТИКА: Отправляемые атрибуты');
      log.d('═══════════════════════════════════════════════════════');
      log.d('✅ Загруженные атрибуты в категории: ${request.categoryId}');
      log.d('   Всего атрибутов: ${_attributes.length}');
      for (final attr in _attributes) {
        log.d('   - ID ${attr.id}: ${attr.title}');
      }
      log.d('');
      log.d('📋 Отправляемые в API:');
      log.d('   value_selected: ${request.attributes['value_selected']}');
      log.d(
        '   values keys: ${(request.attributes['values'] as Map).keys.toList()}',
      );

      // Показываем какие value_id отправляются
      final valueIds = request.attributes['value_selected'] as List<int>;
      if (valueIds.isNotEmpty) {
        log.d('');
        log.d('📊 Поиск атрибутов для каждого value_id:');
        for (final valueId in valueIds) {
          String? foundAttr = '❌ НЕ НАЙДЕНО';
          for (final attr in _attributes) {
            final matchingVal = attr.values
                .where((v) => v.id == valueId)
                .firstOrNull;
            if (matchingVal != null) {
              foundAttr = '✅ ${attr.id}: ${attr.title} = ${matchingVal.value}';
              break;
            }
          }
          log.d('   Value ID $valueId → $foundAttr');
        }
      }

      // Показываем values
      final valuesMap = request.attributes['values'] as Map<String, dynamic>;
      if (valuesMap.isNotEmpty) {
        log.d('');
        log.d('🔢 Числовые/булевы атрибуты (values):');
        valuesMap.forEach((attrIdStr, value) {
          final attrId = int.tryParse(attrIdStr);
          final attr = _attributes.firstWhere(
            (a) => a.id == attrId,
            orElse: () =>
                Attribute(id: 0, title: 'UNKNOWN', order: 0, values: []),
          );
          log.d(
            '   Атрибут ID $attrIdStr: ${attr.title} (в категории: ${attr.id != 0 ? "ДА" : "НЕТ"}) = $value',
          );
        });
      }
      log.d('═══════════════════════════════════════════════════════');
      log.d('');

      // Выбираем нужный метод API в зависимости от режима
      final response = _isEditMode && widget.advertId != null
          ? await ApiService.updateAdvert(
              widget.advertId!,
              request,
              token: token,
            )
          : await ApiService.createAdvert(request, token: token);

      if (response['success'] != true) {
        // Hide loading
        setState(() {
          _isPublishing = false;
          _publishingProgress = '';
        });

        // Handle validation errors (422) or other errors
        String errorMessage = response['message'] ?? 'Ошибка операции';

        // If there are detailed validation errors, show them
        if (response['errors'] != null && response['errors'] is Map) {
          final errors = response['errors'] as Map<String, dynamic>;
          final errorLines = <String>[];

          errors.forEach((field, messages) {
            if (messages is List && messages.isNotEmpty) {
              errorLines.add('• $field: ${messages.first}');
            } else if (messages is String) {
              errorLines.add('• $field: $messages');
            }
          });

          if (errorLines.isNotEmpty) {
            errorMessage = 'Ошибки валидации:\n${errorLines.join('\n')}';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // Extract advert ID from response
      int? advertId;
      if (_isEditMode && widget.advertId != null) {
        // При редактировании используем существующий ID
        advertId = widget.advertId;
        // log.d('✅ Using existing advert ID for updating: $advertId');
      } else if (response['data'] != null) {
        if (response['data'] is List && (response['data'] as List).isNotEmpty) {
          // API returns data as a list, get first item
          final data = (response['data'] as List)[0] as Map<String, dynamic>;
          advertId = data['id'] as int?;
          // log.d('✅ Extracted advert ID from list: $advertId');
        } else if (response['data'] is Map) {
          // Alternative format: data as direct map
          final data = response['data'] as Map<String, dynamic>;
          advertId = data['id'] as int?;
          // log.d('✅ Extracted advert ID from map: $advertId');
        }
      }

      if (advertId == null) {
        // log.d('❌ ERROR: No advert ID returned from API!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: не удалось получить ID объявления'),
            duration: Duration(seconds: 5),
          ),
        );
        setState(() {
          _isPublishing = false;
          _publishingProgress = '';
        });
        return;
      }

      // log.d(_isEditMode
      //     ? '✅ Advert updated with ID: $advertId'
      //     : '✅ Advert created with ID: $advertId');

      // Step 2: Upload images if any
      if (_images.isNotEmpty) {
        try {
          setState(() {
            _publishingProgress =
                'Загрузка изображений (0/${_images.length})...';
          });

          final imagePaths = _images.map((file) => file.path).toList();
          await ApiService.uploadAdvertImages(
            advertId,
            imagePaths,
            token: token,
          );
        } catch (e) {
          // log.d('⚠️ Warning: Error uploading images: $e');
          // Don't fail the entire operation if images fail - advert is already created
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Объявление создано, но ошибка при загрузке изображений: $e',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      // Hide loading
      setState(() {
        _isPublishing = false;
        _publishingProgress = '';
      });

      // Log to console
      // log.d('✅ Объявление отправлено в админку');
      // log.d('Response: ${response['message']}');

      // 🗑️ Инвалидируем кеш объявлений и счётчиков профиля после публикации
      AppCacheService().invalidate(CacheKeys.profileListingsCounts);
      await AppCacheService().invalidateByPrefix(CacheKeys.advertsPrefix);
      // log.d('🗑️ Кеш профиля инвалидирован - счетчики обновятся при возврате');

      // Show moderation dialog
      _showModerationDialog();
    } catch (e) {
      setState(() {
        _isPublishing = false;
        _publishingProgress = '';
      });

      // Check if it's a token expiration error
      if (e.toString().contains('Token expired') ||
          e.toString().contains('Токен истек')) {
        // Trigger logout and redirect to login
        context.read<AuthBloc>().add(const LogoutEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сессия истекла. Пожалуйста, войдите снова'),
          ),
        );
        // Navigate to login screen
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/sign_in', (Route<dynamic> route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showModerationDialog() {
    final isEditMode = _isEditMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isEditMode ? 'Объявление обновлено' : 'Объявление на модерации',
          ),
          content: Text(
            isEditMode
                ? 'Изменения в объявлении отправлены на модерацию. После проверки они будут применены.'
                : 'Ваше объявление отправлено на модерацию. После проверки оно будет опубликовано.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog

                // Получить ID категории
                final categoryId = widget.categoryId ?? _editAdvertCategoryId;

                // Навигировать на my_listings_screen с параметрами
                if (categoryId != null) {
                  Navigator.of(context).pushReplacementNamed(
                    MyListingsScreen.routeName,
                    arguments: {
                      'categoryId': categoryId,
                      'tabIndex': 3, // Вкладка "На модерации"
                    },
                  );
                } else {
                  // Если нет categoryId, просто вернуться
                  Navigator.of(context).pop();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _reloadFilterData();
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(
              onRetry: () {
                context.read<ConnectivityBloc>().add(
                  const CheckConnectivityEvent(),
                );
              },
            );
          }
          return Scaffold(
            backgroundColor: primaryBackground,
            body: SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding,
                  vertical: 19,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: Color.fromARGB(255, 255, 255, 255),
                          ),
                        ),
                        const SizedBox(width: 13),
                        const Text(
                          'Создайте объявление',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),

                    const Text(
                      'Опишите товар или услугу',
                      style: TextStyle(color: textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 17),

                    GestureDetector(
                      onTap: () {
                        _showImageSourceActionSheet(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _images.isEmpty
                              ? (_fieldErrors.containsKey('images')
                                    ? const Color(0xFF381a1a)
                                    : secondaryBackground)
                              : primaryBackground,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: _images.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 28.0),
                                      child: Icon(
                                        Icons.add_circle_outline,
                                        color:
                                            _fieldErrors.containsKey('images')
                                            ? const Color(0xFFff7272)
                                            : textSecondary,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 27.0,
                                      ),
                                      child: Text(
                                        'Добавить изображение',
                                        style: TextStyle(
                                          color:
                                              _fieldErrors.containsKey('images')
                                              ? const Color(0xFFff7272)
                                              : textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 115 / 89,
                                    ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _images.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _images.length) {
                                    return GestureDetector(
                                      onTap: () =>
                                          _showImageSourceActionSheet(context),
                                      child: Container(
                                        width: 115,
                                        height: 89,
                                        decoration: BoxDecoration(
                                          color: formBackground,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: textSecondary,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Container(
                                    width: 115,
                                    height: 89,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Image.file(
                                            _images[index],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 7,
                                          right: 11,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    if (_fieldErrors.containsKey('images'))
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          _fieldErrors['images'] ??
                              'Добавьте хотя бы одно изображение',
                          style: const TextStyle(
                            color: Color(0xFFFF1744),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 13),

                    _buildTextField(
                      label: 'Заголовок объявления',
                      hint: 'Например, уютная 2-комнатная квартира',
                      fieldKey: 'title',
                      controller: _titleController,
                    ),
                    if (!_fieldErrors.containsKey('title'))
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          'Введите не менее 16 символов',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 15),

                    _buildDropdown(
                      label: 'Категория',
                      fieldKey: 'category',
                      hint: _categoryName.isEmpty
                          ? 'Загрузка...'
                          : _categoryName,
                      subtitle: 'Недвижимость',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RealEstateSubcategoriesScreen(),
                          ),
                        );
                      },
                      showChangeText: true,
                    ),
                    const SizedBox(height: 13),

                    _buildTextField(
                      label: 'Описание',
                      hint:
                          'Чем больше информации вы укажете о вашей квартире, тем привлекательнее она будет для покупателей. Без ссылок, телефонов, матершинных слов.',
                      fieldKey: 'description',
                      minLength: 70,
                      maxLength: 1000,
                      maxLines: 4,
                      controller: _descriptionController,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Text(
                          'Цена*',
                          style: TextStyle(color: textPrimary, fontSize: 16),
                        ),
                        if (_fieldErrors.containsKey('price'))
                          const Text(
                            ' *',
                            style: TextStyle(
                              color: Color(0xFFFF1744),
                              fontSize: 16,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _fieldErrors.containsKey('price')
                                  ? const Color(0xFF381a1a)
                                  : formBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      color: _fieldErrors.containsKey('price')
                                          ? const Color(0xFFff7272)
                                          : textPrimary,
                                    ),
                                    onChanged: (value) {
                                      // Очищаем ошибку при вводе цены
                                      if (value.isNotEmpty) {
                                        setState(() {
                                          _fieldErrors.remove('price');
                                        });
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: '1 000 000',
                                      hintStyle: TextStyle(
                                        color: _fieldErrors.containsKey('price')
                                            ? const Color(0xFFff7272)
                                            : textSecondary,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: formBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          width: 53,
                          height: 48,
                          alignment: Alignment.center,
                          child: Text(
                            '₽',
                            style: TextStyle(color: textPrimary, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    if (_fieldErrors.containsKey('price'))
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          _fieldErrors['price'] ?? 'Ошибка заполнения',
                          style: const TextStyle(
                            color: Color(0xFFFF1744),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 15),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ...(List<Attribute>.from(_attributes)
                            ..sort((a, b) => a.order.compareTo(b.order)))
                          .where((attr) {
                            return attr.title.isNotEmpty;
                          })
                          .map(
                            (attr) => Column(
                              children: [
                                _buildDynamicFilter(attr),
                                const SizedBox(height: 9),
                              ],
                            ),
                          )
                          .toList(),

                    // ============================================================
                    // REQUIRED CONSENT ATTRIBUTE: "Вам предложат цену"
                    // ============================================================
                    // Hidden - functionality moved to "Возможен торг" checkbox
                    // When user checks "Возможен торг", this attribute is automatically set to true
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Автопродление',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Обьявление будет деактивирано\n через 30 дней',
                              style: TextStyle(color: textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                        const Spacer(),

                        CustomSwitch(
                          value: isAutoRenewal,
                          onChanged: (v) => setState(() => isAutoRenewal = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ADDRESS SECTION WITH API
                    // Region field
                    _buildDropdown(
                      label: 'Ваша область*',
                      fieldKey: 'region',
                      hint: _selectedRegion.isEmpty
                          ? 'Выберите область'
                          : _selectedRegion.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: () {
                        if (_regions.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Области загружаются...'),
                            ),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SelectionDialog(
                              title: 'Выберите область',
                              options: _regions
                                  .map((r) => r['name'] as String)
                                  .toList(),
                              selectedOptions: _selectedRegion,
                              onSelectionChanged: (Set<String> selected) {
                                if (selected.isNotEmpty) {
                                  final selectedRegionName = selected.first;
                                  final regionIndex = _regions.indexWhere(
                                    (r) => r['name'] == selectedRegionName,
                                  );
                                  int? regionId;
                                  if (regionIndex >= 0) {
                                    regionId =
                                        _regions[regionIndex]['id'] as int?;
                                  }
                                  setState(() {
                                    _selectedRegion = selected;
                                    _selectedRegionId = regionId;
                                    mainRegionId = regionId;
                                    _fieldErrors.remove(
                                      'region',
                                    ); // Clear error on selection
                                    _selectedCity.clear();
                                    _selectedStreet.clear();
                                    _selectedCityId = null;
                                    _selectedStreetId = null;
                                    _cities.clear();
                                    _streets.clear();
                                    _selectedBuilding.clear();
                                    _selectedBuildingId = null;
                                    _buildings.clear();
                                    // 🆕 Очищаем кеш результатов поиска городов
                                    _lastCitiesSearchResults.clear();
                                  });

                                  log.d(
                                    '🎯 Пользователь выбрал регион: "$selectedRegionName" (ID: $regionId)',
                                  );

                                  // 🔄 Загружаем города с API сразу после выбора региона
                                  if (regionId != null) {
                                    _loadCitiesForSelectedRegion();
                                  }
                                }
                              },
                              allowMultipleSelection: false,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 9),

                    // City field
                    _buildDropdown(
                      label: 'Ваш город*',
                      fieldKey: 'city',
                      hint: _selectedCity.isEmpty
                          ? 'Выберите город'
                          : _selectedCity.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: _selectedRegionId == null
                          ? null
                          : () {
                              // 🆕 Упрощенное открытие диалога города
                              // Поиск теперь делается ДИНАМИЧЕСКИ в диалоге при вводе пользователя
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CitySelectionDialog(
                                    title: 'Ваш город',
                                    options: _cities
                                        .map((c) => c['name'] as String)
                                        .toList(), // показываем уже загруженные города
                                    selectedOptions: _selectedCity,
                                    onSelectionChanged: (Set<String> selected) {
                                      if (selected.isNotEmpty) {
                                        final selectedCityName = selected.first;

                                        // 🆕 Ищем ID города в кеше результатов поиска API
                                        int? cityId =
                                            _lastCitiesSearchResults[selectedCityName];
                                        int? mainRegionId = _selectedRegionId;

                                        log.d('');
                                        log.d('✅ City selected from dialog:');
                                        log.d('   - Name: "$selectedCityName"');
                                        log.d(
                                          '   - Looking in cache: ${_lastCitiesSearchResults.keys.toList()}',
                                        );
                                        log.d('   - Found ID: $cityId');
                                        log.d('   - Region ID: $mainRegionId');

                                        if (cityId == null) {
                                          log.w(
                                            '   ⚠️ WARNING: City not found in cache! This should not happen.',
                                          );
                                          log.w(
                                            '   ⚠️ Will try to search for city ID via API...',
                                          );
                                        }

                                        setState(() {
                                          _selectedCity = selected;
                                          _selectedCityId = cityId;
                                          _selectedRegionId = mainRegionId;
                                          _fieldErrors.remove('city');
                                          _selectedStreet.clear();
                                          _selectedStreetId = null;
                                          _streets.clear();
                                          _selectedBuilding.clear();
                                          _selectedBuildingId = null;
                                          _buildings.clear();
                                          // 🆕 Очищаем кеш результатов поиска улиц при смене города
                                          _lastStreetsSearchResults.clear();
                                        });
                                        log.d('');
                                      }
                                    },
                                    // 🆕 Callback для поиска через API
                                    onSearchQuery: _searchCitiesAPI,
                                  );
                                },
                              );
                            },
                    ),
                    const SizedBox(height: 9),

                    // Street field
                    _buildDropdown(
                      label: 'Улица*',
                      fieldKey: 'street',
                      hint: _selectedStreet.isEmpty
                          ? 'Выберите улицу'
                          : _selectedStreet.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: _selectedCityId == null
                          ? null
                          : () async {
                              log.d('');
                              log.d(
                                '🔍 [STREET] Пользователь нажал на "Улица"',
                              );
                              log.d(
                                '   - _selectedCity: ${_selectedCity.toList()}',
                              );
                              log.d('   - _selectedCityId: $_selectedCityId');
                              log.d('   - _streets.length: ${_streets.length}');

                              // Load streets for selected city
                              if (_streets.isEmpty && _selectedCityId != null) {
                                log.d('   → Загружаем улицы с API...');
                                try {
                                  final token = TokenService.currentToken;

                                  // 🔧 ИСПРАВКА: Используем "ул" вместо названия города
                                  // Это позволяет API вернуть ВСЕ улицы города (до 20)
                                  // вместо фильтрации по названию города
                                  const String searchQuery = 'ул';

                                  log.d(
                                    '   - Поисковый запрос БЕЗ обработки: "$searchQuery"',
                                  );
                                  log.d(
                                    '   - Длина строки: ${searchQuery.length} символов',
                                  );

                                  final response =
                                      await AddressService.searchAddresses(
                                        query: searchQuery,
                                        token: token,
                                        types: ['street'],
                                        filters: _selectedCityId != null
                                            ? {'city_id': _selectedCityId}
                                            : null,
                                      );

                                  log.d(
                                    '🔍 Поиск улиц для города ID: $_selectedCityId',
                                  );
                                  log.d(
                                    '📋 API вернул ${response.data.length} результатов',
                                  );

                                  final uniqueStreets =
                                      <String, Map<String, dynamic>>{};
                                  int filteredStreets = 0;
                                  for (final result in response.data) {
                                    // Filter by city on client side
                                    if (result.city?.id == _selectedCityId &&
                                        result.street != null) {
                                      // IMPORTANT: Store both main_region and region IDs from API response
                                      uniqueStreets[result.street!.name] = {
                                        'name': result.street!.name,
                                        'id': result.street!.id,
                                        'city_id': result.city!.id,
                                        'main_region_id':
                                            result.main_region?.id,
                                        'region_id': result.region?.id,
                                      };
                                      log.d(
                                        '   ✅ ${result.street!.name} [id=${result.street!.id}]',
                                      );
                                    } else if (result.street != null) {
                                      filteredStreets++;
                                      log.d(
                                        '   ❌ ${result.street!.name} - city.id=${result.city?.id}, ожидаем $_selectedCityId',
                                      );
                                    }
                                  }

                                  log.d(
                                    '   ✅ Прошло фильтр: ${uniqueStreets.length}',
                                  );
                                  log.d('   ❌ Отфильтровано: $filteredStreets');

                                  if (uniqueStreets.isEmpty) {
                                    log.w(
                                      '   ⚠️ WARNING: Не найдено ни одной улицы!',
                                    );
                                    log.w(
                                      '   На сумму ${response.data.length} результатов от API',
                                    );
                                  }

                                  log.d('');

                                  setState(() {
                                    _streets = uniqueStreets.values.toList();
                                  });
                                } catch (e) {
                                  log.d('❌ Error loading streets: $e');
                                  log.d('');
                                }
                              } else if (_streets.isEmpty) {
                                log.d('   ❌ Не могу загрузить улицы:');
                                log.d(
                                  '       - _selectedCityId: $_selectedCityId',
                                );
                                log.d(
                                  '       - _streets.isEmpty: ${_streets.isEmpty}',
                                );
                                log.d('');
                              } else {
                                log.d(
                                  '   → Улицы уже в кеше, показываем диалог',
                                );
                                log.d('');
                              }

                              if (_streets.isNotEmpty) {
                                log.d(
                                  '🔓 Открываем диалог улиц (${_streets.length} улиц)',
                                );
                                log.d(
                                  '   Улицы: ${_streets.map((s) => s['name']).toList()}',
                                );
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return StreetSelectionDialog(
                                      title: 'Выберите улицу',
                                      options: _streets
                                          .map((s) => s['name'] as String)
                                          .toList(),
                                      selectedOptions: _selectedStreet,
                                      onSelectionChanged: (Set<String> selected) {
                                        if (selected.isNotEmpty) {
                                          final selectedStreetName =
                                              selected.first;

                                          // 🆕 Сначала ищем ID в кеше результатов поиска API
                                          int? streetId =
                                              _lastStreetsSearchResults[selectedStreetName];
                                          int? cityIdFromStreet;

                                          log.d('');
                                          log.d(
                                            '✅ Street selected from dialog:',
                                          );
                                          log.d(
                                            '   - Name: "$selectedStreetName"',
                                          );
                                          log.d(
                                            '   - Looking in cache: ${_lastStreetsSearchResults.keys.toList()}',
                                          );
                                          log.d(
                                            '   - Found ID in cache: $streetId',
                                          );

                                          // Если не нашли в кеше - ищем в локальном списке _streets
                                          if (streetId == null) {
                                            log.d(
                                              '   → Searching in local _streets list...',
                                            );
                                            final streetIndex = _streets
                                                .indexWhere(
                                                  (s) =>
                                                      s['name'] ==
                                                      selectedStreetName,
                                                );
                                            if (streetIndex >= 0) {
                                              streetId =
                                                  _streets[streetIndex]['id']
                                                      as int?;
                                              cityIdFromStreet =
                                                  _streets[streetIndex]['city_id']
                                                      as int?;
                                              log.d(
                                                '   ✅ Found in local list: ID=$streetId, cityId=$cityIdFromStreet',
                                              );
                                            } else {
                                              log.w(
                                                '   ❌ Not found in local list either!',
                                              );
                                            }
                                          } else {
                                            log.d('   ✅ Found in cache');
                                          }

                                          setState(() {
                                            _selectedStreet = selected;
                                            _selectedStreetId = streetId;
                                            if (cityIdFromStreet != null) {
                                              _selectedCityId =
                                                  cityIdFromStreet;
                                            }
                                            _fieldErrors.remove('street');
                                            _selectedBuilding.clear();
                                            _selectedBuildingId = null;
                                            _buildings.clear();
                                          });

                                          log.d('   - Final ID: $streetId');
                                          log.d('');
                                        }
                                      },
                                      // 🆕 Добавляем callback для поиска через API
                                      onSearchQuery: _searchStreetsAPI,
                                    );
                                  },
                                );
                              }
                            },
                    ),
                    const SizedBox(height: 9),

                    // Building number field - dropdown selection
                    _buildDropdown(
                      label: 'Номер дома',
                      hint: _selectedBuilding.isEmpty
                          ? 'Выберите номер дома'
                          : _selectedBuilding.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: _selectedStreetId == null
                          ? null
                          : () async {
                              // Load buildings for selected street
                              if (_buildings.isEmpty &&
                                  _selectedStreetId != null) {
                                await _loadBuildingsForSelectedStreet();
                              }

                              if (_buildings.isNotEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return SelectionDialog(
                                      title: 'Выберите номер дома',
                                      options: _buildings
                                          .map((b) => b['name'] as String)
                                          .toList(),
                                      selectedOptions: _selectedBuilding,
                                      onSelectionChanged: (Set<String> selected) {
                                        if (selected.isNotEmpty) {
                                          final selectedBuildingName =
                                              selected.first;
                                          final buildingIndex = _buildings
                                              .indexWhere(
                                                (b) =>
                                                    b['name'] ==
                                                    selectedBuildingName,
                                              );
                                          int? buildingId;
                                          if (buildingIndex >= 0) {
                                            buildingId =
                                                _buildings[buildingIndex]['id']
                                                    as int?;
                                          }
                                          setState(() {
                                            _selectedBuilding = selected;
                                            _selectedBuildingId = buildingId;
                                            _buildingController.text =
                                                selectedBuildingName;
                                          });
                                        }
                                      },
                                      allowMultipleSelection: false,
                                    );
                                  },
                                );
                              }
                            },
                    ),
                    const SizedBox(height: 9),

                    const Text(
                      'Местоположение на карте',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 9),

                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: formBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.map_outlined,
                          color: textSecondary,
                          size: 40,
                        ),
                      ),
                    ),

                    const SizedBox(height: 27),

                    const Text(
                      'Ваши контактные данные',
                      style: TextStyle(color: textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 18),

                    _buildTextField(
                      label: 'Контактное лицо*',
                      hint: 'Александр',
                      fieldKey: 'contactName',
                      controller: _contactNameController,
                    ),
                    const SizedBox(height: 9),

                    _buildTextField(
                      label: 'Электронная почта',
                      hint: 'AlexAlex@mail.ru',
                      fieldKey: 'email',
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 9),

                    _buildTextField(
                      label: 'Номер телефона 1*',
                      hint: '+7 949 456 65 56',
                      fieldKey: 'phone1',
                      keyboardType: TextInputType.phone,
                      controller: _phone1Controller,
                    ),
                    const SizedBox(height: 9),

                    _buildTextField(
                      label: 'Номер телефона 2',
                      hint: '+7 949 456 65 56',
                      fieldKey: 'phone2',
                      keyboardType: TextInputType.phone,
                      controller: _phone2Controller,
                    ),
                    const SizedBox(height: 9),

                    _buildTextField(
                      label: 'Ссылка на ваш чат в Max',
                      hint: 'https://Namename',
                      fieldKey: 'telegram',
                      controller: _telegramController,
                    ),
                    const SizedBox(height: 9),

                    // _buildTextField(
                    //   label: 'Ссылка на ваш whatsapp',
                    //   hint: 'https://whatsapp/Namename',
                    //   controller: _whatsappController,
                    // ),
                    const SizedBox(height: 22),

                    // ============ Special attribute: "Вам предложат цену" ============
                    // СКРЫТО НА ЭКРАНЕ - логика отправки остается в _collectFormData()
                    // и _publishAdvert(), но UI не отображается
                    // GestureDetector и checkbox для 1048 удалены из build()
                    // _buildButton(
                    //   'Предпросмотр',
                    //   onPressed: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) =>
                    //             const PublicationTariffScreen(),
                    //       ),
                    //     );
                    //   },
                    //   isPrimary: _selectedAction == 'preview',
                    // ),
                    // const SizedBox(height: 10),
                    if (_isPublishing)
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                minimumSize: const Size.fromHeight(51),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              onPressed: null,
                              icon: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isEditMode
                                        ? 'Обновление объявления...'
                                        : 'Публикация объявления...',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _publishingProgress,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      _buildButton(
                        _isEditMode ? 'Обновить' : 'Опубликовать',
                        onPressed: _publishAdvert,
                        isPrimary: _selectedAction == 'publish',
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds style header that displays submission style (styleSingle)
  /// Shows the attribute style code above the field label
  /// styleSingle is used during form submission and contains values like A1, B1, C1, D1, E1, F, G1, H, I
  Widget _buildStyleHeader(Attribute attr) {
    // For submission mode, use styleSingle (API style for form submission)
    // For viewing mode, use style (usually empty from API)
    final displayStyle = _isSubmissionMode
        ? (attr.styleSingle ?? '')
        : attr.style;
    final stylePrefix = _isSubmissionMode ? 'Style2' : 'Style';

    // ALWAYS show style for debugging - remove isEmpty check
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* // Показывает стили над полями для отладки и валидации правильности отображения */
        if (displayStyle.isNotEmpty)
          /* // Показывает стили над полями для отладки и валидации правильности отображения */
          // Text(
          //   '$stylePrefix: $displayStyle',
          //   style: const TextStyle(
          //     color: Color(0xFFFF1744), // Red color for debug visibility
          //     fontSize: 12,
          //     fontWeight: FontWeight.w600,
          //     letterSpacing: 0.3,
          //   ),
          // ),
          if (displayStyle.isNotEmpty) const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    String? fieldKey,
    int maxLines = 1,
    int minLength = 0,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = fieldKey != null && _fieldErrors.containsKey(fieldKey);
    final errorMessage = hasError ? _fieldErrors[fieldKey] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: textPrimary, fontSize: 16),
            ),
            if (hasError)
              const Text(
                ' *',
                style: TextStyle(color: Color(0xFFFF1744), fontSize: 16),
              ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFF381a1a) : formBackground,
            borderRadius: BorderRadius.circular(6),
            // border: hasError
            //     ? Border.all(color: const Color(0xFFFF1744), width: 1)
            //     : null,
          ),
          child: TextField(
            controller: controller,
            minLines: maxLines == 1 ? 1 : maxLines,
            maxLines: null,
            maxLength: maxLength,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              color: hasError
                  ? const Color(0xFFff7272)
                  : const Color.fromARGB(255, 255, 255, 255),
            ),
            onChanged: (value) {
              // Очищаем ошибку при вводе текста в обязательное поле
              if (fieldKey != null && value.isNotEmpty) {
                setState(() {
                  _fieldErrors.remove(fieldKey);
                });
              }
              // Вызываем оригинальный обработчик если есть
              onChanged?.call(value);
            },
            expands: false,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: hasError ? const Color(0xFFff7272) : textSecondary,
                fontSize: 14,
              ),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              errorMessage ?? 'Ошибка заполнения',
              style: const TextStyle(
                color: Color(0xFFFF1744),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else if (minLength > 0)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Введите не менее $minLength символов',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    String? fieldKey,
    VoidCallback? onTap,
    String? subtitle,
    Widget? icon,
    bool showChangeText = false,
  }) {
    final hasError = fieldKey != null && _fieldErrors.containsKey(fieldKey);
    final errorMessage = hasError ? _fieldErrors[fieldKey] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
              if (hasError)
                const Text(
                  ' *',
                  style: TextStyle(color: Color(0xFFFF1744), fontSize: 16),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: subtitle != null ? 60 : 45,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: hasError ? const Color(0xFF381a1a) : formBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: subtitle != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              hint,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasError
                                    ? const Color(0xFFff7272)
                                    : (hint == 'Выбрать' || hint.isEmpty
                                          ? const Color(0xFF7A7A7A)
                                          : const Color.fromARGB(
                                              255,
                                              255,
                                              255,
                                              255,
                                            )),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xFF7A7A7A),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          hint,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasError
                                ? const Color(0xFFff7272)
                                : (hint == 'Выбрать' || hint.isEmpty
                                      ? const Color(0xFF7A7A7A)
                                      : const Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        )),
                            fontSize: 14,
                          ),
                        ),
                ),
                if (showChangeText)
                  Text(
                    'Изменить',
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                if (icon != null) icon,
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              errorMessage ?? 'Ошибка заполнения',
              style: const TextStyle(
                color: Color(0xFFFF1744),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChoiceButton(
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? activeIconColor : Colors.transparent,
        side: isSelected ? null : const BorderSide(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : textPrimary,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildButton(
    String text, {
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? activeIconColor : primaryBackground,
          side: isPrimary ? null : const BorderSide(color: Colors.white),
          minimumSize: const Size.fromHeight(51),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(color: isPrimary ? Colors.white : textPrimary),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAreaRangeField() {
    // Build special field for total area - dynamically get attribute ID
    final areaAttrId = _attributeResolver.getAreaAttributeId();

    if (areaAttrId == null) {
      // log.d('⚠️ Area attribute ID not found, skipping field');
      return const SizedBox.shrink();
    }

    _selectedValues[areaAttrId] ??= '';

    final controller = _controllers.putIfAbsent(
      areaAttrId,
      () => TextEditingController(text: _selectedValues[areaAttrId] ?? ''),
    );

    return Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: textPrimary),
        decoration: const InputDecoration(
          hintText: 'Введите',
          hintStyle: TextStyle(color: textSecondary, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: (value) {
          // log.d('onChanged for $areaAttrId area: $value');
          setState(() {
            _selectedValues[areaAttrId] = value;
          });
        },
      ),
    );
  }

  Widget _buildDynamicFilter(Attribute attr) {
    // Render based on ATTRIBUTES FLAGS FIRST, then style
    // According to ui_filter_styles.md documentation:
    // - Флаги (is_range, is_multiple, is_popup, is_special_design, is_title_hidden) имеют ВЫСШИЙ приоритет
    // - Style (A-I) используется как подтверждение
    // - Названия полей используются только для исключений/переопределений
    //
    // ВАЖНО: Эта логика должна работать с ДИНАМИЧЕСКИ добавляемыми полями,
    // которые могут добавиться на сервере ПОСЛЕ написания этого кода!

    // Debug logging for style mapping
    // log.d(
    //   '🎨 Building filter: ID=${attr.id}, Title=${attr.title}, Style=${attr.style}, styleSingle=${attr.styleSingle ?? 'null'}, '
    //   'is_range=${attr.isRange}, is_multiple=${attr.isMultiple}, '
    //   'is_popup=${attr.isPopup}, is_special_design=${attr.isSpecialDesign}, '
    //   'is_title_hidden=${attr.isTitleHidden}, values_count=${attr.values.length}',
    // );

    // Also print all field names in a compact way to find the exact "За месяц" name
    // log.d(
    //   '📋 FIELD: ID=${attr.id.toString().padLeft(4)} | Title: ${attr.title} | Style: ${attr.style}${attr.styleSingle != null ? ', styleSingle: ${attr.styleSingle}' : ''}',
    // );

    // Special logging for "За месяц" field to debug its parameters
    // Check multiple variations of the field name
    bool isMonthField =
        attr.title.toLowerCase().contains('месяц') ||
        attr.title.toLowerCase().contains('month') ||
        attr.title.toLowerCase().contains('year') ||
        attr.title.toLowerCase().contains('период') ||
        attr.title.toLowerCase().contains('время') ||
        attr.title.contains('месяц') ||
        attr.id == 999;

    if (isMonthField) {
      // log.d('');
      // log.d('═════════════════════════════════════════════════════════════');
      // log.d('🔍 SPECIAL DEBUG: Field "${attr.title}" (ID=${attr.id})');
      // log.d('═════════════════════════════════════════════════════════════');
      // log.d('📊 FULL PARAMETERS:');
      // log.d('  • style: "${attr.style}"');
      // log.d('  • is_range: ${attr.isRange}');
      // log.d('  • is_multiple: ${attr.isMultiple}');
      // log.d('  • is_popup: ${attr.isPopup}');
      // log.d('  • is_special_design: ${attr.isSpecialDesign}');
      // log.d('  • is_title_hidden: ${attr.isTitleHidden}');
      // log.d('  • is_required: ${attr.isRequired}');
      // log.d('  • is_hidden: ${attr.isHidden}');
      // log.d('  • is_filter: ${attr.isFilter}');
      // log.d('  • data_type: "${attr.dataType}"');
      // log.d('  • values_count: ${attr.values.length}');
      // log.d('  • values: ${attr.values.map((v) => v.value).toList()}');
      // log.d('═════════════════════════════════════════════════════════════');
      // log.d('');
    }

    // =================================================================
    // PRIORITY 1: Используем ФЛАГИ И СВОЙСТВА атрибута
    // Это работает для ЛЮБЫХ новых полей, которые добавят на сервере
    // =================================================================

    // Случай 1: Скрытые чекбоксы (Style I)
    // Флаги: is_title_hidden=true, is_multiple=true
    // Пример: Без комиссии, Возможность обмена, Только с доставкой и т.д.
    if (attr.isTitleHidden && attr.isMultiple && attr.values.isNotEmpty) {
      // log.d();
      return _buildCheckboxField(attr);
    }

    // Случай 1.5: Скрытый одиночный чекбокс (Style I - одиночный)
    // Флаги: is_title_hidden=true, is_multiple=false, есть values
    // Пример: Только с доставкой, Только с исполнителем (styleSingle=I)
    if (attr.isTitleHidden && !attr.isMultiple && attr.values.isNotEmpty) {
      // log.d();
      return _buildCheckboxField(attr);
    }

    // Случай 1.5.5: Стиль A1 (текстовое поле с валютой)
    // Флаги: styleSingle='A1'
    // Пример: Цена, Средний чек (числовое поле с суффиксом валюты)
    if (attr.styleSingle == 'A1') {
      // log.d();
      return _buildA1Field(attr);
    }

    // Случай 1.5.6: Стиль B1 (одиночный чекбокс - SUBMISSION MODE)
    // Флаги: styleSingle='B1'
    // Пример: Возможен торг, Без комиссии, Возможность обмена (при подаче объявления)
    if (attr.styleSingle == 'B1') {
      // log.d();
      return _buildB1Field(attr);
    }

    // Случай 1.6: Специальное числовое поле (styleSingle=G1)
    // Флаги: styleSingle='G1'
    // Пример: Общее площадь, Жилая площадь (одиночное числовое поле)
    if (attr.styleSingle == 'G1') {
      // log.d();
      return _buildG1Field(attr);
    }

    // Случай 1.7: Стиль F - Множественный выбор в popUp (styleSingle=F - SUBMISSION MODE)
    // Флаги: styleSingle='F'
    // Пример: Множественный выбор, Инфраструктура (много опций в popUp)
    // ВАЖНО: F это ВСЕГДА множественный выбор с SQUARE CHECKBOXES
    if (attr.styleSingle == 'F') {
      // log.d();
      // Гарантируем isMultiple=true для множественного выбора с чекбоксами
      Attribute fAttr = attr.copyWith(isMultiple: true);
      return _buildMultipleSelectPopup(fAttr);
    }

    // Случай 1.8: Стиль E1 - Диапазон (styleSingle=E1 - SUBMISSION MODE)
    // Флаги: styleSingle='E1'
    // Пример: Этажи, Площадь (диапазон при подаче объявления)
    if (attr.styleSingle == 'E1') {
      // log.d();
      return _buildRangeField(attr, isInteger: attr.dataType == 'integer');
    }

    // Случай 1.9: Стиль J1 - Календарь выбора дат и времени (styleSingle=J1 - SUBMISSION MODE)
    // Флаги: styleSingle='J1'
    // Пример: Календарь аренды, Время и дата для услуг (виджет с двумя датами/временем)
    if (attr.styleSingle == 'J1') {
      // log.d();
      return _buildJ1Field(attr);
    }

    // Случай 1.10: Стиль K1/K - K-Calendar выбора дат и времени (styleSingle=K1 или K - SUBMISSION MODE)
    // Флаги: styleSingle='K1' или styleSingle='K'
    // Пример: K-Calendar аренда, Время и дата для услуг (компактный формат)
    if (attr.styleSingle == 'K1' || attr.styleSingle == 'K') {
      // log.d();
      return _buildK1Field(attr);
    }

    // Случай 1.11: Стиль C1 - Кнопки (styleSingle=C1 - SUBMISSION MODE)
    // Флаги: styleSingle='C1'
    // Пример: Меблированная, Вид объекта, Ипотека (кнопки при подаче объявления)
    // ВАЖНО: это одиночный выбор в виде кнопок (как D1 для dropdown, E1 для range)
    if (attr.styleSingle == 'C1') {
      // log.d();
      return _buildSpecialDesignField(attr);
    }

    // Случай 2: Простой чекбокс (Style B)
    // Флаги: НЕ is_multiple (или is_multiple=false), есть values
    // Но НЕ is_title_hidden
    // Пример: Возможен торг, Меблированная (когда это одиночный чекбокс)
    if (!attr.isMultiple &&
        !attr.isTitleHidden &&
        attr.values.isNotEmpty &&
        attr.values.length <= 2) {
      // log.d();
      return _buildCheckboxField(attr);
    }

    // Случай 3: Диапазон (Style E)
    // Флаг: is_range=true
    // Пример: Этаж, Площадь, Цена и т.д.
    if (attr.isRange) {
      // log.d();
      return _buildRangeField(attr, isInteger: attr.dataType == 'integer');
    }

    // Случай 3.5: Style D1 Popup с RADIO BUTTONS (Одиночный выбор - SUBMISSION MODE)
    // Флаги: is_popup=true, is_multiple=true (но это API quirk), НЕ Style F
    // Пример: Тип дома (13 вариантов, но RADIO buttons - только ОДНО значение можно выбрать)
    // ВАЖНО: несмотря на флаг is_multiple=true, это показывает RADIO BUTTONS и одиночный выбор

    // Логика: D1 Popup это popup + multiple, но БЕЗ явного Style F marker
    // Style F обычно определяется через values.length > 5 в Case 7
    // D1 Popup это "другие" popup + multiple поля (типа ID=1)
    bool isD1PopupWithoutF =
        (attr.styleSingle == 'D1' || attr.style == 'D') &&
        attr.isMultiple &&
        attr
            .values
            .isNotEmpty; // Note: is_popup может быть false в API, но мы переопределим его

    if (attr.id == 1) {
      // log.d();
    }

    if (isD1PopupWithoutF) {
      // log.d();
      // D1 должен показывать POPUP с RADIO buttons - переопределяем isMultiple=false и is_popup=true
      Attribute d1Attr = attr.copyWith(isMultiple: false, isPopup: true);
      return _buildMultipleSelectPopup(d1Attr);
    }

    // Случай 4: Style D Popup с CHECKBOXES (Множественный выбор - VIEWING MODE)
    // Флаги: is_popup=true, is_multiple=true, есть values, style='D' (БЕЗ styleSingle=D1)
    // Пример: Все поля которые имеют is_popup=true из API и НЕ имеют styleSingle=D1
    // ВАЖНО: это показывает CHECKBOXES и позволяет выбрать НЕСКОЛЬКО значений
    if (attr.isPopup &&
        attr.isMultiple &&
        attr.styleSingle != 'D1' &&
        attr.values.isNotEmpty) {
      // log.d();
      // D (без D1) должен показывать CHECKBOXES - оставляем isMultiple=true
      return _buildMultipleSelectPopup(attr);
    }

    // Случай 5: Группа кнопок (Style C)
    // Флаги: is_special_design=true, есть values (2, 3 или больше)
    // Примеры: Меблированная (2 кнопки), Вид сделки (3 кнопки)
    if (attr.isSpecialDesign && attr.values.isNotEmpty) {
      // log.d();
      return _buildSpecialDesignField(attr);
    }

    // Случай 6: Множественный выбор (Style D)
    // Флаги: is_multiple=true, есть values, НО НЕ is_popup
    // Пример: Комфорт, Инфраструктура (как dropdown, не popup)
    if (attr.isMultiple && !attr.isPopup && attr.values.isNotEmpty) {
      // log.d();
      return _buildMultipleSelectDropdown(attr);
    }

    // Случай 7: Один выбор из значений (Single select dropdown/popup)
    // Флаги: есть values, НО НЕ is_multiple, НЕ is_range, НЕ is_special_design
    if (!attr.isMultiple &&
        !attr.isRange &&
        !attr.isSpecialDesign &&
        attr.values.isNotEmpty) {
      // Style F: Много вариантов (> 5) - POPUP с CHECKBOXES (MULTIPLE selection)
      // Examples: Тип сделки, Ландшафт, Инфраструктура (7, 20, 16 опций)
      if (attr.values.length > 5) {
        // log.d();
        // Override: Allow multiple selection for Style F with many options
        Attribute multiAttr = attr.copyWith(isMultiple: true);
        return _buildMultipleSelectPopup(multiAttr);
      } else {
        // Мало вариантов (2-5) - Single select dropdown
        // Example: Санузел (5 опций)
        // log.d();
        return _buildSingleSelectDropdown(attr);
      }
    }

    // Случай 8: Текстовое поле (Style A, H)
    // Флаги: НЕТ values (текстовое поле без предопределенных вариантов)
    // Пример: Название ЖК, Описание и т.д.
    if (attr.values.isEmpty) {
      // log.d();
      return _buildTextInputField(attr);
    }

    // =================================================================
    // PRIORITY 2: Если не совпадает ни один случай выше - используем STYLE
    // =================================================================
    // log.d();

    switch (attr.style) {
      case 'A':
      case 'A1':
        // Style A/A1: Текстовое поле (text input)
        return _buildTextInputField(attr);

      case 'B':
        // Style B: Чекбокс (single value checkbox)
        return _buildCheckboxField(attr);

      case 'C':
        // Style C: Да/Нет переключатель (buttons for yes/no)
        // With is_special_design flag for button styling
        return _buildSpecialDesignField(attr);

      case 'D':
      case 'D1':
        // Style D/D1: Множественный выбор
        // If is_popup=true: show as modal, else show as dropdown list
        if (attr.isPopup) {
          return _buildMultipleSelectPopup(attr);
        } else {
          return _buildMultipleSelectDropdown(attr);
        }

      case 'E':
      case 'E1':
        // Style E/E1: Диапазон (range with от/до)
        return _buildRangeField(attr, isInteger: attr.dataType == 'integer');

      case 'F':
        // Style F: Множественный выбор в попапе (modal/popup selection)
        // Always show as popup with checkboxes
        return _buildMultipleSelectPopup(attr);

      case 'G':
      case 'G1':
        // Style G/G1: Числовое поле (numeric input)
        // If is_range=true: show range fields, else single input
        if (attr.isRange) {
          return _buildRangeField(attr, isInteger: false);
        } else {
          return _buildTextInputField(attr);
        }

      case 'H':
        // Style H: Текстовое поле (text input)
        return _buildTextInputField(attr);

      case 'I':
        // Style I: Скрытые чекбоксы (hidden without title, checkbox list)
        // Multiple checkboxes with is_title_hidden=true
        return _buildHiddenCheckboxField(attr);

      case 'manual':
        // Manual style - custom UI rendering
        return _buildTextInputField(attr);

      default:
        // =================================================================
        // PRIORITY 3: Finale fallback для неизвестных стилей
        // Используем логику на основе флагов еще раз
        // =================================================================
        // log.d('❌ Unknown style "${attr.style}", using final fallback logic');
        if (attr.isPopup && attr.isMultiple && attr.values.isNotEmpty) {
          return _buildMultipleSelectPopup(attr);
        } else if (attr.isRange) {
          return _buildRangeField(attr, isInteger: attr.dataType == 'integer');
        } else if (attr.isMultiple && attr.values.isNotEmpty) {
          return _buildMultipleSelectDropdown(attr);
        } else if (attr.values.isNotEmpty) {
          return _buildSpecialDesignField(attr);
        } else {
          return _buildTextInputField(attr);
        }
    }
  }

  // Style B1: Single checkbox (SUBMISSION MODE)
  Widget _buildB1Field(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? false;
    bool selected = _selectedValues[attr.id] is bool
        ? _selectedValues[attr.id]
        : false;

    // StyleSingle B1: Display as single checkbox with label
    // Example: Возможен торг, Без комиссии, Возможность обмена (submission mode)
    // Shows label text left and checkbox right in a row

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        GestureDetector(
          onTap: () => setState(() {
            _selectedValues[attr.id] = !selected;
          }),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  attr.title + (attr.isRequired ? '*' : ''),
                  style: const TextStyle(color: textPrimary, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              CustomCheckbox(
                value: selected,
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

  // Style B: Single checkbox
  Widget _buildCheckboxField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? false;
    bool selected = _selectedValues[attr.id] is bool
        ? _selectedValues[attr.id]
        : false;

    // According to documentation:
    // Style B: Single checkbox (usually for one value like "Возможен торг")
    // If no title is hidden, show as row with label and checkbox

    // Check if this is "Возможен торг" checkbox to link it with "предложат цену" attribute
    bool isBargainCheckbox = attr.title.toLowerCase().contains('торг');
    final offerPriceAttrId = isBargainCheckbox
        ? _attributeResolver.getOfferPriceAttributeId()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        GestureDetector(
          onTap: () => setState(() {
            _selectedValues[attr.id] = !selected;
            // "Возможен торг" и "Вам предложат цену" теперь независимы
            // "Вам предложат цену" всегда true по умолчанию и не меняется
          }),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  attr.values.isNotEmpty
                      ? attr.values[0].value
                      : (attr.title + (attr.isRequired ? '*' : '')),
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              CustomCheckbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    _selectedValues[attr.id] = v;
                    // "Возможен торг" и "Вам предложат цену" теперь независимы
                    // "Вам предложат цену" всегда true по умолчанию и не меняется
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Style J1: Rent time widget (calendar with date and time selection)
  Widget _buildJ1Field(Attribute attr) {
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
    Map<String, dynamic> timeData =
        _selectedValues[attrId] as Map<String, dynamic>;

    // Убеждаемся, что все ключи существуют
    timeData.putIfAbsent('dateFrom', () => null);
    timeData.putIfAbsent('timeFrom', () => null);
    timeData.putIfAbsent('dateTo', () => null);
    timeData.putIfAbsent('timeTo', () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          Text(
            attr.title + (attr.isRequired ? '*' : ''),
            style: const TextStyle(color: textPrimary, fontSize: 16),
          ),
        if (!attr.isTitleHidden) const SizedBox(height: 9),
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

  // Style K1/K: K-Calendar with date and time selection (compact format)
  Widget _buildK1Field(Attribute attr) {
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
    Map<String, dynamic> timeData =
        _selectedValues[attrId] as Map<String, dynamic>;

    // Убеждаемся, что все ключи существуют
    timeData.putIfAbsent('dateFrom', () => null);
    timeData.putIfAbsent('timeFrom', () => null);
    timeData.putIfAbsent('dateTo', () => null);
    timeData.putIfAbsent('timeTo', () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          Text(
            attr.title + (attr.isRequired ? '*' : ''),
            style: const TextStyle(color: textPrimary, fontSize: 16),
          ),
        if (!attr.isTitleHidden) const SizedBox(height: 9),
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

  // Style A1: Numeric field with currency (price field)
  Widget _buildA1Field(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';
    final controller = _controllers.putIfAbsent(attr.id, () {
      final value = _selectedValues[attr.id];
      final textValue = value is String ? value : (value?.toString() ?? '');
      return TextEditingController(text: textValue);
    });

    // StyleSingle A1: Display as single numeric input field with currency suffix
    // Example: Цена, Средний чек
    // Shows number input with ₽ (ruble) symbol in separate container

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        Text(
          attr.title + (attr.isRequired ? '*' : ''),
          style: const TextStyle(color: textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: textPrimary, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: '1 000 000',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => _selectedValues[attr.id] = value.trim(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              width: 53,
              height: 48,
              alignment: Alignment.center,
              child: const Text(
                '₽',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Style G1: Special numeric field (single numeric input)
  Widget _buildG1Field(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';

    // 🔧 При редактировании: если контроллер уже существует с предзаполненным значением, используем его
    // При создании: создаем новый контроллер с пустым значением
    final controller = _controllers.putIfAbsent(attr.id, () {
      final value = _selectedValues[attr.id];
      log.d('🔍 Creating G1 controller for attr ${attr.id} "${attr.title}"');
      log.d(
        '   value from _selectedValues: $value (type: ${value.runtimeType})',
      );

      final textValue = value is String ? value : (value?.toString() ?? '');
      log.d('   textValue: "$textValue"');

      return TextEditingController(text: textValue);
    });

    // DEBUG: проверяем что контроллер имеет правильное значение
    log.d(
      '   Current controller text: "${controller.text}" for attr ${attr.id}',
    );

    // StyleSingle G1: Display as single numeric input field
    // Example: Общее площадь, Жилая площадь
    // Uses same styling as other text input fields (style A/H)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        _buildTextField(
          label: attr.title + (attr.isRequired ? '*' : ''),
          hint: 'Цифрами',
          fieldKey: 'attr_${attr.id}',
          keyboardType: TextInputType.number,
          controller: controller,
          onChanged: (value) => _selectedValues[attr.id] = value.trim(),
        ),
      ],
    );
  }

  // Style C / C1: Special design (button group with variable number of options)
  Widget _buildSpecialDesignField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';

    // ✅ Обработка различных типов значений (String или Set)
    String selected = '';
    final value = _selectedValues[attr.id];

    if (value is String) {
      selected = value;
    } else if (value is Set<String> && value.isNotEmpty) {
      // Если значение это Set - берем первый элемент (одиночный выбор для C1)
      selected = value.first;
      log.d('   ✅ C1/C field: Extracted value from Set: $selected');
    }

    // According to documentation:
    // Style C with is_special_design=true: Show as button group
    // Style C1 (styleSingle=C1): Show as button group (submission mode)
    // Can have 2, 3, or more button options (Да/Нет, Совместная/Продажа/Аренда, etc.)

    final fieldKey = 'attr_${attr.id}';
    final hasError = _fieldErrors.containsKey(fieldKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          Row(
            children: [
              Text(
                attr.title,
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              if (attr.isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: hasError
                        ? const Color(0xFFFF1744)
                        : const Color(0xFFFF1744),
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        if (attr.values.isNotEmpty)
          _buildButtonGrid(
            buttons: attr.values,
            selectedValue: selected,
            onButtonPressed: (value) {
              setState(() {
                _selectedValues[attr.id] = value;
                _fieldErrors.remove(fieldKey);
              });
            },
          ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Обязательное поле',
              style: const TextStyle(
                color: Color(0xFFFF1744),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a flexible grid of buttons that adapts to screen width
  /// 2 buttons: 2 columns (50% each) in Row
  /// 3 buttons: 3 columns (33% each) in Row
  /// 4+ buttons: 3 columns per row with wrapping
  Widget _buildButtonGrid({
    required List<Value> buttons,
    required String selectedValue,
    required Function(String) onButtonPressed,
  }) {
    if (buttons.isEmpty) return const SizedBox.shrink();

    final spacing = 10.0;

    // For 2 buttons: Row with 50% width each
    if (buttons.length == 2) {
      return Row(
        children: [
          Expanded(
            child: _buildChoiceButton(
              buttons[0].value,
              selectedValue == buttons[0].value,
              () => onButtonPressed(buttons[0].value),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildChoiceButton(
              buttons[1].value,
              selectedValue == buttons[1].value,
              () => onButtonPressed(buttons[1].value),
            ),
          ),
        ],
      );
    }

    // For 3 buttons: Row with 33% width each (all in one row)
    if (buttons.length == 3) {
      return Row(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            Expanded(
              child: _buildChoiceButton(
                buttons[i].value,
                selectedValue == buttons[i].value,
                () => onButtonPressed(buttons[i].value),
              ),
            ),
            if (i < buttons.length - 1) const SizedBox(width: 10),
          ],
        ],
      );
    }

    // For 4+ buttons: Wrap with flexible sizing
    // Each button takes appropriate width and wraps to next row if needed
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (int i = 0; i < buttons.length; i++)
          Flexible(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _buildChoiceButton(
                buttons[i].value,
                selectedValue == buttons[i].value,
                () => onButtonPressed(buttons[i].value),
              ),
            ),
          ),
      ],
    );
  }

  // Style D: Multiple select (dropdown list or popup based on is_popup flag)
  Widget _buildSingleSelectDropdown(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';
    String selected = _selectedValues[attr.id] is String
        ? (_selectedValues[attr.id] as String)
        : '';

    // Single select dropdown (not multiple, not buttons)
    // Example: Санузел (Раздельный/Смежный)

    return _buildDropdown(
      label: attr.isTitleHidden
          ? ''
          : attr.title + (attr.isRequired ? '*' : ''),
      fieldKey: 'attr_${attr.id}',
      hint: selected.isEmpty ? 'Выбрать' : selected,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return SelectionDialog(
              title: attr.title.isEmpty ? 'Выбор' : attr.title,
              options: attr.values.map((v) => v.value).toList(),
              selectedOptions: selected.isEmpty ? {} : {selected},
              onSelectionChanged: (Set<String> newSelected) {
                setState(() {
                  _selectedValues[attr.id] = newSelected.isEmpty
                      ? ''
                      : newSelected.first;
                  _fieldErrors.remove('attr_${attr.id}');
                });
              },
              allowMultipleSelection: false,
            );
          },
        );
      },
    );
  }

  Widget _buildMultipleSelectDropdown(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    // According to documentation:
    // - Style D with is_popup=false: show as dropdown/selection dialog
    // - Style D with is_popup=true: show as popup modal

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        _buildDropdown(
          label: attr.isTitleHidden
              ? ''
              : attr.title + (attr.isRequired ? '*' : ''),
          fieldKey: 'attr_${attr.id}',
          hint: selected.isEmpty ? 'Выбрать' : selected.join(', '),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textSecondary,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SelectionDialog(
                  title: attr.title.isEmpty ? 'Выбор' : attr.title,
                  options: attr.values.map((v) => v.value).toList(),
                  selectedOptions: selected,
                  onSelectionChanged: (Set<String> newSelected) {
                    setState(() {
                      _selectedValues[attr.id] = newSelected;
                      _fieldErrors.remove('attr_${attr.id}');
                    });
                  },
                  allowMultipleSelection: attr.isMultiple,
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Style E/E1 & G/G1: Range fields (E for integer, G for decimal)
  Widget _buildRangeField(Attribute attr, {required bool isInteger}) {
    _selectedValues[attr.id] ??= {'min': '', 'max': ''};
    Map<String, dynamic> rangeMap = _selectedValues[attr.id] is Map
        ? _selectedValues[attr.id] as Map<String, dynamic>
        : {'min': '', 'max': ''};

    final minStr = rangeMap['min']?.toString() ?? '';
    final maxStr = rangeMap['max']?.toString() ?? '';
    Map<String, String> range = {'min': minStr, 'max': maxStr};

    final minKey = attr.id * 2;
    final maxKey = attr.id * 2 + 1;
    final controllerMin = _controllers.putIfAbsent(
      minKey,
      () => TextEditingController(text: range['min']),
    );
    final controllerMax = _controllers.putIfAbsent(
      maxKey,
      () => TextEditingController(text: range['max']),
    );

    // Determine keyboard type based on style and data_type
    TextInputType keyboardType;
    if (attr.dataType == 'numeric' || attr.style == 'G' || attr.style == 'G1') {
      keyboardType = TextInputType.numberWithOptions(decimal: true);
    } else {
      keyboardType = TextInputType.number;
    }

    final fieldKey = 'attr_${attr.id}';
    final hasError = _fieldErrors.containsKey(fieldKey);
    final hintColor = hasError ? const Color(0xFFff7272) : textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        if (!attr.isTitleHidden)
          Text(
            attr.title + (attr.isRequired ? '*' : ''),
            style: const TextStyle(color: textPrimary, fontSize: 16),
          ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: hasError ? const Color(0xFF381a1a) : formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controllerMin,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    color: hasError ? const Color(0xFFff7272) : textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'От',
                    hintStyle: TextStyle(color: hintColor, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      range['min'] = value;
                      _selectedValues[attr.id] = range;
                      // Clear error when user inputs
                      if (value.isNotEmpty) {
                        _fieldErrors.remove(fieldKey);
                      }
                    });
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  'Из',
                  style: TextStyle(
                    color: hasError ? const Color(0xFFff7272) : textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: hasError ? const Color(0xFF381a1a) : formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controllerMax,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    color: hasError ? const Color(0xFFff7272) : textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'До',
                    hintStyle: TextStyle(color: hintColor, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      range['max'] = value;
                      _selectedValues[attr.id] = range;
                      // Clear error when user inputs
                      if (value.isNotEmpty) {
                        _fieldErrors.remove(fieldKey);
                      }
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Заполните минимальное и максимальное значение',
              style: const TextStyle(
                color: Color(0xFFFF1744),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // Style F & D (with is_popup=true): Multiple select (popup/modal)
  Widget _buildMultipleSelectPopup(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    // log.d(
    //   '🔍 Building multiple select popup for attr ${attr.id} "${attr.title}"',
    // );
    // log.d('   selected values: ${selected.toList()}');
    // log.d('   available options: ${attr.values.map((v) => v.value).toList()}');

    // According to documentation:
    // Style F: Always popup with checkboxes
    // Style D with is_popup=true: Popup with radio or checkboxes
    // If is_multiple=true: checkboxes, else: radio buttons

    // Специальная обработка заголовка для переноса строки
    String displayLabel = attr.isTitleHidden
        ? ''
        : attr.title + (attr.isRequired ? '*' : '');

    // Helper function to intelligently wrap long text with line breaks
    // Instead of hardcoding specific field names
    String _wrapLongText(String text) {
      const maxCharsPerLine = 20; // Максимум символов в одной строке
      if (text.length <= maxCharsPerLine) {
        return text;
      }

      // Пытаемся разбить по пробелам
      final words = text.split(' ');
      if (words.length == 1) {
        // Слово без пробелов - разбиваем в середине
        return '${text.substring(0, text.length ~/ 2)}\n${text.substring(text.length ~/ 2)}';
      }

      // Ищем оптимальную точку разрыва
      String line1 = '';
      String line2 = '';
      for (int i = 0; i < words.length; i++) {
        if ((line1 + ' ' + words[i]).length <= maxCharsPerLine) {
          line1 += (line1.isEmpty ? '' : ' ') + words[i];
        } else {
          line2 = words.sublist(i).join(' ');
          break;
        }
      }

      return line2.isEmpty ? text : '$line1\n$line2';
    }

    // Заголовок для диалога с переносом строки для длинных названий
    String dialogTitle = attr.title.isEmpty ? 'Выбор' : attr.title;
    dialogTitle = _wrapLongText(dialogTitle);

    // Обработка длинных значений опций с переносом строки
    List<String> processedOptions = attr.values.map((v) {
      String value = v.value;
      return _wrapLongText(value);
    }).toList();

    // Также обрабатываем выбранные значения для отображения в hint
    // Но сохраняем маппинг для восстановления оригинальных значений
    Map<String, String> wrappedToOriginal = {};
    Set<String> processedSelected = selected.map((s) {
      String wrapped = _wrapLongText(s);
      if (wrapped != s) {
        wrappedToOriginal[wrapped] = s;
      }
      return wrapped;
    }).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        _buildDropdown(
          label: displayLabel,
          fieldKey: 'attr_${attr.id}',
          hint: processedSelected.isEmpty
              ? 'Выбрать'
              : processedSelected.join(', '),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textSecondary,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SelectionDialog(
                  title: dialogTitle,
                  options: processedOptions,
                  selectedOptions: processedSelected,
                  onSelectionChanged: (Set<String> newSelected) {
                    // Восстанавливаем оригинальные значения перед сохранением
                    Set<String> originalSelected = newSelected.map((s) {
                      return wrappedToOriginal[s] ?? s;
                    }).toSet();
                    setState(() {
                      _selectedValues[attr.id] = originalSelected;
                      _fieldErrors.remove('attr_${attr.id}');
                    });
                  },
                  allowMultipleSelection: attr.isMultiple,
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Style A/A1/H: Text input field
  Widget _buildTextInputField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';
    final controller = _controllers.putIfAbsent(attr.id, () {
      final value = _selectedValues[attr.id];
      final textValue = value is String ? value : (value?.toString() ?? '');
      return TextEditingController(text: textValue);
    });

    // Determine keyboard type based on data_type
    TextInputType keyboardType = TextInputType.text;
    if (attr.dataType == 'integer') {
      keyboardType = TextInputType.number;
    } else if (attr.dataType == 'numeric') {
      keyboardType = TextInputType.numberWithOptions(decimal: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        _buildTextField(
          label: attr.isTitleHidden
              ? ''
              : attr.title + (attr.isRequired ? '*' : ''),
          hint: attr.dataType == 'integer'
              ? 'Цифрами'
              : (attr.dataType == 'numeric' ? 'Число' : 'Текст'),
          keyboardType: keyboardType,
          controller: controller,
          onChanged: (value) => _selectedValues[attr.id] = value.trim(),
        ),
      ],
    );
  }

  // Style I: Hidden checkbox (no title, checkbox list)
  Widget _buildHiddenCheckboxField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? false;
    bool selected = _selectedValues[attr.id] is bool
        ? _selectedValues[attr.id]
        : false;

    // According to documentation:
    // Style I: Hidden checkbox with is_title_hidden=true
    // Show checkbox label from values[0].value, not from title
    // Example: "Без комиссии", "Возможность обмена", etc.

    String checkboxLabel = '';
    if (attr.values.isNotEmpty) {
      checkboxLabel = attr.values[0].value;
    } else if (attr.title.isNotEmpty && !attr.isTitleHidden) {
      checkboxLabel = attr.title;
    }

    if (checkboxLabel.isEmpty) {
      return const SizedBox.shrink(); // Skip rendering if no label
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyleHeader(attr),
        GestureDetector(
          onTap: () => setState(() => _selectedValues[attr.id] = !selected),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  checkboxLabel,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              CustomCheckbox(
                value: selected,
                onChanged: (v) => setState(() => _selectedValues[attr.id] = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
