import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/street_selection_dialog.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import '../../../constants.dart';
import '../../../services/api_service.dart';
import '../../../services/address_service.dart';
import '../../../services/user_service.dart';
import '../../../models/filter_models.dart';
import '../../../models/create_advert_model.dart';
import '../../../hive_service.dart';
import 'package:lidle/pages/add_listing/real_estate_subcategories_screen.dart';
import 'package:lidle/pages/add_listing/publication_tariff_screen.dart';

// ============================================================
// "Виджет: Экран добавления аренды квартиры в недвижимость"
// ============================================================
class DynamicFilter extends StatefulWidget {
  static const String routeName = '/add-real-estate-apt';

  final int? categoryId;

  const DynamicFilter({super.key, this.categoryId});

  @override
  State<DynamicFilter> createState() => _DynamicFilterState();
}

// ============================================================
// "Класс состояния: Управление состоянием экрана аренды квартиры"
// ============================================================
class _DynamicFilterState extends State<DynamicFilter> {
  List<Attribute> _attributes = [];
  Map<int, dynamic> _selectedValues = {};
  bool _isLoading = true;
  bool _isPublishing = false;
  String _publishingProgress = '';
  Map<int, TextEditingController> _controllers = {};

  // Category name
  String _categoryName = '';

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
  final TextEditingController _buildingController = TextEditingController();

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
  int? _selectedBuildingId;

  @override
  void initState() {
    super.initState();
    // Initialize attribute 1048 (Вам предложат цену) to true by default
    _selectedValues[1048] = true;

    _loadAttributes();
    _loadUserContacts();
    _loadRegions();
    // Автозаполнение для тестирования
    Future.delayed(const Duration(milliseconds: 500), () {
      _autoFillFormForTesting();
    });
  }

  @override
  void dispose() {
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

  Future<void> _loadAttributes() async {
    try {
      print('Loading filters for category: ${widget.categoryId ?? 2}');
      final token = await HiveService.getUserData('token');
      final response = await ApiService.getMetaFilters(
        categoryId: widget.categoryId ?? 2,
        token: token,
      );
      print('Loaded ${response.filters.length} filters');
      for (final attr in response.filters) {
        print(
          '📊 Filter: ID=${attr.id}, Title=${attr.title}, Order=${attr.order}, Values=${attr.values.length}',
        );
      }

      // Convert to mutable list and add missing attribute 1048
      final mutableFilters = List<Attribute>.from(response.filters);

      // Add hidden attribute 1048 (Вам предложат цену) if not present
      // This attribute is REQUIRED by API but not returned by /meta/filters endpoint
      final hasAttribute1048 = mutableFilters.any((a) => a.id == 1048);
      if (!hasAttribute1048) {
        print(
          '🔧 Adding missing attribute 1048 (Вам предложат цену) - required for advert creation',
        );
        final attribute1048 = Attribute(
          id: 1048,
          title: 'Вам предложат цену',
          isFilter: false,
          isRange: false,
          isMultiple: false,
          isHidden: true,
          isRequired: true,
          isTitleHidden: true,
          isSpecialDesign: false,
          isMaxValue: false,
          dataType: null,
          order: 999,
          values: const [],
        );
        mutableFilters.add(attribute1048);
        print('✅ Attribute 1048 added to filters list');
      }

      if (mounted) {
        setState(() {
          _attributes = mutableFilters;
          _isLoading = false;
        });
      }

      // Load category name
      _loadCategoryInfo();
    } catch (e) {
      print('Error loading filters from API: $e');
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

  Future<void> _loadRegions() async {
    try {
      print('📍 Loading regions from API...');
      final token = await HiveService.getUserData('token');

      final regions = await ApiService.getRegions(token: token);

      if (mounted) {
        setState(() {
          _regions = regions;
        });
      }
      print('✅ Loaded ${regions.length} regions');
    } catch (e) {
      print('❌ Error loading regions: $e');
      // Try again after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadRegions();
      });
    }
  }

  Future<void> _loadCategoryInfo() async {
    try {
      if (widget.categoryId == null) {
        print('⚠️ Category ID is null, using default name');
        if (mounted) {
          setState(() {
            _categoryName = 'Долгосрочная аренда комнат';
          });
        }
        return;
      }

      final token = await HiveService.getUserData('token');
      print('📦 Loading category info for ID: ${widget.categoryId}');

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
      print('✅ Category name loaded: $_categoryName');
    } catch (e) {
      print('❌ Error loading category info: $e');
      if (mounted) {
        setState(() {
          _categoryName = 'Категория';
        });
      }
    }
  }

  Future<void> _loadUserContacts() async {
    try {
      final token = await HiveService.getUserData('token');
      print('📱 Token obtained, loading user contacts...');
      if (token == null) {
        print('❌ Token is null, cannot load contacts');
        return;
      }

      // Load phones - REQUIRED for publishing
      try {
        print('📞 Loading phones from /me/settings/phones...');
        final phonesResponse = await ApiService.get(
          '/me/settings/phones',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (phonesResponse['data'] is List) {
          _userPhones = List<Map<String, dynamic>>.from(phonesResponse['data']);
          print('✅ Loaded phones: ${_userPhones.length} phone(s)');
        } else {
          print('⚠️ Phones response format incorrect');
        }
      } catch (e) {
        print('❌ Error loading phones: $e');
      }

      // Load emails
      try {
        print('📧 Loading emails from /me/settings/emails...');
        final emailsResponse = await ApiService.get(
          '/me/settings/emails',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (emailsResponse['data'] is List) {
          _userEmails = List<Map<String, dynamic>>.from(emailsResponse['data']);
          print('✅ Loaded emails: ${_userEmails.length} email(s)');
        } else {
          print('⚠️ Emails response format incorrect');
        }
      } catch (e) {
        print('❌ Error loading emails: $e');
      }

      // Load telegrams
      try {
        print('💬 Loading telegrams from /me/settings/telegrams...');
        final telegramsResponse = await ApiService.get(
          '/me/settings/telegrams',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (telegramsResponse['data'] is List) {
          _userTelegrams = List<Map<String, dynamic>>.from(
            telegramsResponse['data'],
          );
          print('✅ Loaded telegrams: ${_userTelegrams.length} telegram(s)');
        } else {
          print('⚠️ Telegrams response format incorrect');
        }
      } catch (e) {
        print('❌ Error loading telegrams: $e');
      }

      // Load whatsapps
      try {
        print('💬 Loading whatsapps from /me/settings/whatsapps...');
        final whatsappsResponse = await ApiService.get(
          '/me/settings/whatsapps',
          token: token,
        );
        // API returns { "data": [...] } without success field
        if (whatsappsResponse['data'] is List) {
          _userWhatsapps = List<Map<String, dynamic>>.from(
            whatsappsResponse['data'],
          );
          print('✅ Loaded whatsapps: ${_userWhatsapps.length} whatsapp(s)');
        } else {
          print('⚠️ Whatsapps response format incorrect');
        }
      } catch (e) {
        print('❌ Error loading whatsapps: $e');
      }

      // Load user profile to get name
      try {
        print('👤 Loading user profile from /me...');
        final userProfile = await UserService.getProfile(token: token);
        print(
          '✅ Loaded user profile: ${userProfile.name} ${userProfile.lastName}',
        );

        // Fill contact fields with user data
        if (mounted) {
          setState(() {
            // Fill contact name from profile
            final fullName = '${userProfile.name} ${userProfile.lastName}'
                .trim();
            _contactNameController.text = fullName;
            print('✅ Filled contact name: $fullName');

            // Fill email from first available email
            if (_userEmails.isNotEmpty) {
              final email = _userEmails[0]['email'] ?? '';
              _emailController.text = email;
              print('✅ Filled email: $email');
            }

            // Fill phone1 from first available phone
            if (_userPhones.isNotEmpty) {
              final phone = _userPhones[0]['phone'] ?? '';
              _phone1Controller.text = phone;
              print('✅ Filled phone1: $phone');
            }
          });
        }
      } catch (e) {
        print('⚠️ Error loading user profile: $e');
      }

      if (mounted) {
        setState(() {});
      }
      print('✅ User contacts loading complete');
    } catch (e) {
      print('❌ Error loading user contacts: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  // 🧪 ТЕСТОВОЕ АВТОЗАПОЛНЕНИЕ ФОРМЫ
  void _autoFillFormForTesting() {
    if (!mounted) return;

    print('🧪 AUTO-FILLING HIDDEN FIELDS FOR TESTING...');

    setState(() {
      // Основные поля объявления - ЗАКОММЕНТИРОВАНО (видимые поля)
      // _titleController.text = 'Просторная однокомнатная квартира';
      // _descriptionController.text =
      //     'Комфортная однокомнатная квартира площадью 45 кв.м, расположена в тихом районе с хорошей инфраструктурой. Полностью меблирована, есть все необходимое для жизни.';
      // _priceController.text = '120000';

      // Контакты - только если они ещё не загружены из API - ЗАКОММЕНТИРОВАНО (видимые поля)
      // (Если они уже заполнены из API, не перезаписываем)
      // if (_contactNameController.text.isEmpty) {
      //   _contactNameController.text = 'Юрий ';
      // }
      // if (_emailController.text.isEmpty) {
      //   _emailController.text = '1workyury02@gmail.com';
      // }
      // if (_phone1Controller.text.isEmpty) {
      //   _phone1Controller.text = '+79254499552';
      // }

      // Выбор контактов из загруженных - ЗАКОММЕНТИРОВАНО (видимые поля)
      // if (_userPhones.isNotEmpty) {
      //   print('✅ Selected first phone: ${_userPhones[0]['phone']}');
      // }
      // if (_userEmails.isNotEmpty) {
      //   print('✅ Selected first email: ${_userEmails[0]['email']}');
      // }

      // Автозаполнение адресных полей - ЗАКОММЕНТИРОВАНО (видимые поля)
      // if (_regions.isNotEmpty) {
      //   final firstRegion = _regions[0];
      //   _selectedRegion = {firstRegion['name'] ?? 'Region'};
      //   _selectedRegionId = firstRegion['id'];
      //   print('✅ Auto-selected region: ${_selectedRegion}');
      // }

      // После выбора региона автоматически загружаем города (отложено) - ЗАКОММЕНТИРОВАНО
      // Future.delayed(const Duration(milliseconds: 300), () async {
      //   if (_selectedRegionId != null && _cities.isEmpty) {
      //     await _loadCitiesForSelectedRegion();
      //     // Затем автоматически выбираем первый город
      //     if (_cities.isNotEmpty && _selectedCity.isEmpty) {
      //       final firstCity = _cities[0];
      //       setState(() {
      //         _selectedCity = {firstCity['name'] ?? 'City'};
      //         _selectedCityId = firstCity['id'];
      //         print('✅ Auto-selected city: ${_selectedCity}');
      //       });

      //       // После выбора города автоматически загружаем улицы
      //       Future.delayed(const Duration(milliseconds: 300), () async {
      //         if (_selectedCityId != null && _streets.isEmpty) {
      //           await _loadStreetsForSelectedCity();
      //           // Затем автоматически выбираем первую улицу
      //           if (_streets.isNotEmpty && _selectedStreet.isEmpty) {
      //             final firstStreet = _streets[0];
      //             setState(() {
      //               _selectedStreet = {firstStreet['name'] ?? 'Street'};
      //               _selectedStreetId = firstStreet['id'];
      //               print('✅ Auto-selected street: ${_selectedStreet}');
      //             });
      //           }
      //         });
      //       });
      //     }
      //   }
      // });

      // Автозаполнение атрибутов фильтров (невидимые поля - оставляем)
      // 1040 - Этаж (floor)
      _selectedValues[1040] = {'min': 4, 'max': 5};

      // 1039 - Название ЖК (Building name)
      _selectedValues[1039] = 'Новый дом';

      // 6 - Количество комнат (Rooms) - 3 комнаты
      _selectedValues[6] = '3';

      // 17 - Инфраструктура (Infrastructure)
      _selectedValues[17] = 'Исторические места';

      // 19 - Частное лицо / Бизнес (Individual/Business)
      _selectedValues[19] = 'Частное лицо';

      // 14 - Комфорт (Comfort)
      _selectedValues[14] = 'Автономное отопление';

      // 1127 - Общая площадь (Total area) - Simple field (not range anymore)
      _selectedValues[1127] = '50';

      // 1048 - Вам предложат цену (Price offer) - REQUIRED boolean attribute
      _selectedValues[1048] = true;

      // NOTE: "Вам предложат цену" filter will be added in _collectFormData
      // since it's not returned by API but required for validation

      print('🧪 Auto-fill completed:');
      // print('   Title: ${_titleController.text}'); - ЗАКОММЕНТИРОВАНО
      // print('   Price: ${_priceController.text}'); - ЗАКОММЕНТИРОВАНО
      print('   Selected values: $_selectedValues');
    });
  }

  /// Загружает города для выбранного региона при автозаполнении
  Future<void> _loadCitiesForSelectedRegion() async {
    if (_selectedRegionId == null) return;

    try {
      final token = await HiveService.getUserData('token');
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
      );

      print(
        '🔍 Auto-load cities: API returned ${response.data.length} results',
      );

      final uniqueCities = <String, int>{};
      for (final result in response.data) {
        if (result.main_region?.id == _selectedRegionId &&
            result.city != null) {
          uniqueCities[result.city!.name] = result.city!.id;
        }
      }

      if (mounted) {
        setState(() {
          _cities = uniqueCities.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
        print('✅ Auto-loaded ${_cities.length} cities');
      }
    } catch (e) {
      print('❌ Error auto-loading cities: $e');
    }
  }

  /// Загружает улицы для выбранного города при автозаполнении
  Future<void> _loadStreetsForSelectedCity() async {
    if (_selectedCityId == null) return;

    try {
      final token = await HiveService.getUserData('token');
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
      );

      print(
        '🔍 Auto-load streets: API returned ${response.data.length} results',
      );

      final uniqueStreets = <String, int>{};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          uniqueStreets[result.street!.name] = result.street!.id;
        }
      }

      if (mounted) {
        setState(() {
          _streets = uniqueStreets.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
        print('✅ Auto-loaded ${_streets.length} streets');
      }
    } catch (e) {
      print('❌ Error auto-loading streets: $e');
    }
  }

  /// Загружает номера домов для выбранной улицы при автозаполнении

  int? mainRegionId = 1; // Track main_region.id for top-level region_id
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
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
                        _pickImage(ImageSource.camera);
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SvgPicture.asset(
                        'assets/showImageSourceActionSheet/image-01.svg',
                      ),
                      title: const Text(
                        'Загрузить фотографию',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImage(ImageSource.gallery);
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

  void _togglePersonType(bool isIndividual) {
    setState(() {
      isIndividualSelected = isIndividual;
      if (isIndividual) {
        _selectedValues[19] = 'Частное лицо';
      } else {
        _selectedValues[19] = 'Бизнес';
      }
    });
  }

  CreateAdvertRequest _collectFormData() {
    // Collect attributes
    final Map<String, dynamic> attributes = {
      'value_selected': <int>[],
      'values': <String, dynamic>{},
    };

    print('Selected values: $_selectedValues');
    print(
      '📋 Available filters: ${_attributes.map((a) => '${a.id}=${a.title}').join(', ')}',
    );

    _selectedValues.forEach((key, value) {
      final attr = _attributes.firstWhere(
        (a) => a.id == key,
        orElse: () => Attribute(id: 0, title: '', order: 0, values: []),
      );
      if (attr.id == 0) {
        print('⚠️ WARNING: Filter ID $key not found in loaded attributes!');
        return;
      }

      print(
        '🔍 Processing attribute ID=$key (${attr.title}), is_multiple=${attr.isMultiple}',
      );

      if (value is Set<String>) {
        // Multiple selection - but check if attribute allows multiple values
        // Some attributes like "Количество комнат" (ID=6) have is_multiple=false
        // These should only send ONE value to the API
        if (attr.isMultiple) {
          // API allows multiple - add all selected values
          print(
            '   Attribute $key (${attr.title}): is_multiple=true, adding all values',
          );
          for (final val in value) {
            final attrValue = attr.values.firstWhere(
              (v) => v.value == val,
              orElse: () => const Value(id: 0, value: ''),
            );
            if (attrValue.id != 0) {
              print(
                '      Added value: ${attrValue.value} (ID=${attrValue.id})',
              );
              attributes['value_selected'].add(attrValue.id);
            }
          }
        } else {
          // API allows only one value - take first
          print(
            '   Attribute $key (${attr.title}): is_multiple=false (SINGLE VALUE ONLY)',
          );
          if (value.isNotEmpty) {
            final firstVal = value.first;
            final attrValue = attr.values.firstWhere(
              (v) => v.value == firstVal,
              orElse: () => const Value(id: 0, value: ''),
            );
            if (attrValue.id != 0) {
              print('   ✅ Adding single value: $firstVal (ID=${attrValue.id})');
              attributes['value_selected'].add(attrValue.id);
            } else {
              print('   ❌ Value "$firstVal" not found in attribute values');
            }
          } else {
            print('   ⚠️ No values selected for is_multiple=false attribute');
          }
        }

        // SPECIAL DIAGNOSTIC: Log attribute 6 handling
        if (key == 6) {
          print('🔍🔍 SPECIAL DIAGNOSTIC FOR ATTRIBUTE 6 (ROOMS):');
          print('   is_multiple: ${attr.isMultiple}');
          print('   Selected values in Set: $value');
          print('   Number of values: ${value.length}');
          print('   All available values for attr 6:');
          for (final v in attr.values) {
            print('      - "${v.value}" (ID=${v.id})');
          }
          if (value.isNotEmpty) {
            value.forEach((val) {
              final matchedValue = attr.values.firstWhere(
                (v) => v.value == val,
                orElse: () => const Value(id: 0, value: ''),
              );
              print('   Value="$val" => ID=${matchedValue.id}');
            });
          }
        }
      } else if (value is Map) {
        // Range values - for attributes like 1040 (floor) - but NOT 1127 anymore
        final minVal = (value['min']?.toString() ?? '').trim();
        final maxVal = (value['max']?.toString() ?? '').trim();
        print(
          'For attr $key (${attr.title}), minVal: "$minVal", maxVal: "$maxVal"',
        );

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
          print('   Added range attr $key: $attrObj');
        }
      } else if (value is String) {
        if (attr.values.isEmpty) {
          // Text field - DO NOT add to attributes.values (API doesn't accept them)
          if (value.isNotEmpty) {
            print(
              '   ⚠️ SKIPPING text field attr $key: "$value" (text fields not sent to API)',
            );
          }
        } else {
          // Single selection - lookup value ID
          final attrValue = attr.values.firstWhere(
            (v) => v.value == value,
            orElse: () => const Value(id: 0, value: ''),
          );
          if (attrValue.id != 0) {
            attributes['value_selected'].add(attrValue.id);
            print(
              '   Added single selection attr $key: $value (ID=${attrValue.id})',
            );
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
    print('🔧 DIAGNOSTIC - Mapping value_ids to attributes:');
    for (final valueId in attributes['value_selected'] as List<int>) {
      String? foundAttrTitle = 'UNKNOWN';
      for (final attr in _attributes) {
        final matchingValue = attr.values.firstWhere(
          (v) => v.id == valueId,
          orElse: () => const Value(id: 0, value: ''),
        );
        if (matchingValue.id != 0) {
          foundAttrTitle = '${attr.id}:${attr.title}';
          print(
            '   value_id=$valueId belongs to attribute: $foundAttrTitle (value="${matchingValue.value}")',
          );
          break;
        }
      }
      if (foundAttrTitle == 'UNKNOWN') {
        print(
          '   value_id=$valueId COULD NOT BE MAPPED - no matching attribute!',
        );
      }
    }
    print('Collected attributes: $attributes');

    // Handle boolean attribute 1048 ("Вам предложат цену")
    // IMPORTANT: 1048 should be in attributes.values, NOT in value_selected!
    // API expects: attributes.values['1048'] = {'value': 1}
    if (_selectedValues.containsKey(1048) && _selectedValues[1048] == true) {
      attributes['values']['1048'] = {'value': 1};
      print('✅ Added attribute 1048 to values (required) as {value: 1}');
    } else {
      // If not explicitly selected, add by default (it's required)
      attributes['values']['1048'] = {'value': 1};
      print('✅ Added default attribute 1048 to values as {value: 1}');
    }

    // Handle required attribute 1127 (Общая площадь - Total area)
    // Now it's a simple field, not a range
    if (_selectedValues.containsKey(1127)) {
      final area = _selectedValues[1127];
      if (area is String && area.isNotEmpty) {
        final areaVal = int.tryParse(area.toString().trim());
        if (areaVal != null) {
          attributes['values']['1127'] = {'value': areaVal};
          print('✅ Attribute 1127 (area) set: value=$areaVal');
        } else {
          // If parsing fails, set default
          attributes['values']['1127'] = {'value': 50};
          print('⚠️ Failed to parse area value, using default: 50');
        }
      } else {
        // Set default area if not selected
        attributes['values']['1127'] = {'value': 50};
        print('✅ Set default 1127: value=50');
      }
    } else {
      // Set default area if not selected
      attributes['values']['1127'] = {'value': 50};
      print('✅ Set default 1127: value=50');
    }

    // NOTE: attribute_1048 (boolean type) is handled separately via toJson() in CreateAdvertRequest
    // It's extracted to top-level and NOT added to value_selected
    // (value_selected should only contain VALUE IDs, not attribute IDs)

    // Collect address
    // NOTE: address will be updated via searchAddresses() in _publishAdvert()
    // This just collects whatever UI values exist
    final Map<String, dynamic> address = {};

    print('Collected address: $address');

    // Collect contacts with proper validation
    // According to API docs: user_phone_id is REQUIRED, user_email_id may be required
    final Map<String, dynamic> contacts = {};

    // Primary phone is required
    if (_userPhones.isNotEmpty) {
      contacts['user_phone_id'] = _userPhones.first['id'];
      print(
        '✅ Using phone ID: ${_userPhones.first['id']} (${_userPhones.first['phone']})',
      );
    }

    // Email handling - ALWAYS include email ID if available
    // API requires email - error message says: "contacts.user_email_id: обязательно для заполнения"
    // This means email is REQUIRED, regardless of verification status
    if (_userEmails.isNotEmpty) {
      final emailData = _userEmails.first;
      final isVerified = emailData['email_verified_at'] != null;

      contacts['user_email_id'] = emailData['id'];
      if (isVerified) {
        print(
          '✅ Using verified email ID: ${emailData['id']} (${emailData['email']})',
        );
      } else {
        print(
          '⚠️ Email NOT verified (email_verified_at=null): ${emailData['email']} - but API requires it, sending anyway',
        );
      }
    } else {
      print('❌ ERROR: No email contacts found!');
    }

    if (_userTelegrams.isNotEmpty) {
      contacts['user_telegram_id'] = _userTelegrams.first['id'];
    }
    if (_userWhatsapps.isNotEmpty) {
      contacts['user_whatsapp_id'] = _userWhatsapps.first['id'];
    }

    print('Collected contacts: $contacts');

    return CreateAdvertRequest(
      name: _titleController.text,
      description: _descriptionController.text,
      price: _priceController.text,
      categoryId: widget.categoryId ?? 2,
      regionId:
          mainRegionId ??
          1, // Use mainRegionId (top-level region), not address.region_id
      address: address,
      attributes: attributes,
      contacts: contacts,
      isAutoRenew: isAutoRenewal,
    );
  }

  Future<void> _publishAdvert() async {
    try {
      // Validate required fields
      if (_titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните заголовок объявления')),
        );
        return;
      }
      if (_descriptionController.text.length < 70) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Описание должно содержать не менее 70 символов'),
          ),
        );
        return;
      }
      if (_priceController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заполните цену')));
        return;
      }
      if (_contactNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните контактное лицо')),
        );
        return;
      }
      if (_phone1Controller.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните номер телефона')),
        );
        return;
      }

      // Debug logging for phone validation
      print('🔍 Publishing advert - phone validation:');
      print('   _userPhones.length: ${_userPhones.length}');
      print('   _userPhones content: $_userPhones');
      print('   _phone1Controller.text: ${_phone1Controller.text}');

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

      // Validate required attributes
      bool isValid = true;
      String errorMessage = '';
      for (final attr in _attributes) {
        if (attr.isRequired) {
          final value = _selectedValues[attr.id];
          if (value == null) {
            isValid = false;
            errorMessage = 'Заполните поле "${attr.title}"';
            break;
          }
          if (value is String && value.isEmpty) {
            isValid = false;
            errorMessage = 'Заполните поле "${attr.title}"';
            break;
          }
          if (value is Map) {
            final minVal = (value['min']?.toString() ?? '').trim();
            final maxVal = (value['max']?.toString() ?? '').trim();
            if (minVal.isEmpty && maxVal.isEmpty) {
              isValid = false;
              errorMessage = 'Заполните поле "${attr.title}"';
              break;
            }
          }
          if (value is Set<String> && value.isEmpty) {
            isValid = false;
            errorMessage = 'Заполните поле "${attr.title}"';
            break;
          }
        }
      }

      // Validate special attribute: "Вам предложат цену" (attribute 1048)
      // This is always required and must be explicitly set
      if (!_selectedValues.containsKey(1048) || _selectedValues[1048] == null) {
        isValid = false;
        errorMessage = 'Необходимо согласиться принимать предложения по цене';
      }

      if (!isValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
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
          final token = await HiveService.getUserData('token');
          if (token != null) {
            print('🔍 Starting 3-step address search...');

            // ============ STEP 1: Search for city WITHOUT filters ============
            // ============ Prepare address from selected API data ============
            // Use already loaded IDs from API searches during dropdown selections
            if (_selectedRegionId == null) {
              errorMessage = 'Пожалуйста, выберите область';
              throw Exception('Region not selected');
            }
            if (_selectedCityId == null) {
              errorMessage = 'Пожалуйста, выберите город';
              throw Exception('City not selected');
            }
            if (_selectedStreetId == null) {
              errorMessage = 'Пожалуйста, выберите улицу';
              throw Exception('Street not selected');
            }
            if (_selectedBuilding.isEmpty || _buildingController.text.isEmpty) {
              errorMessage = 'Пожалуйста, введите номер дома';
              throw Exception('Building number required');
            }

            // Extract region.id (subregion) from selected city/street/building
            int? addressRegionId;

            // Try to get region_id from selected building first
            final buildingIndex = _buildings.indexWhere(
              (b) => b['name'] == _selectedBuilding.first,
            );
            if (buildingIndex >= 0) {
              addressRegionId = _buildings[buildingIndex]['region_id'] as int?;
            }

            // If not found in building, try street
            if (addressRegionId == null && _selectedStreet.isNotEmpty) {
              final streetIndex = _streets.indexWhere(
                (s) => s['name'] == _selectedStreet.first,
              );
              if (streetIndex >= 0) {
                addressRegionId = _streets[streetIndex]['region_id'] as int?;
              }
            }

            // If not found in street, try city
            if (addressRegionId == null && _selectedCity.isNotEmpty) {
              final cityIndex = _cities.indexWhere(
                (c) => c['name'] == _selectedCity.first,
              );
              if (cityIndex >= 0) {
                addressRegionId = _cities[cityIndex]['region_id'] as int?;
              }
            }

            address['region_id'] = addressRegionId;
            address['city_id'] = _selectedCityId;
            address['street_id'] = _selectedStreetId;
            // Не отправляем building_id, так как номер дома вводится вручную
            address['building_number'] = _selectedBuilding.first;

            print('✅ Address prepared from selections:');
            print('   region_id (for address): ${address['region_id']}');
            print('   city_id: ${address['city_id']}');
            print('   street_id: ${address['street_id']}');
            print('   building_number: ${address['building_number']}');
            print(
              '   _selectedRegionId (main_region, for top-level): $_selectedRegionId',
            );
            print('');
            print('📋 DEBUG INFO - Selected values stored:');
            print('   _selectedRegion: $_selectedRegion');
            print('   _selectedRegionId: $_selectedRegionId');
            print('   _selectedCity: $_selectedCity');
            print('   _selectedCityId: $_selectedCityId');
            print('   _selectedStreet: $_selectedStreet');
            print('   _selectedStreetId: $_selectedStreetId');
            print('   _selectedBuilding: $_selectedBuilding');
            print('   _selectedBuildingId: $_selectedBuildingId');
            print('');
            print('📋 DEBUG INFO - Lists content:');
            print(
              '   _regions: ${_regions.map((r) => '${r['name']}(id=${r['id']})').toList()}',
            );
            print(
              '   _cities: ${_cities.map((c) => '${c['name']}(id=${c['id']})').toList()}',
            );
            print(
              '   _streets: ${_streets.map((s) => '${s['name']}(id=${s['id']})').toList()}',
            );
            print(
              '   _buildings: ${_buildings.map((b) => '${b['name']}(id=${b['id']})').toList()}',
            );

            // Recreate request with address from API selections
            if (address.isNotEmpty) {
              // Ensure 1048 is in values (not as separate attribute_1048 key)
              final updatedAttributes = Map<String, dynamic>.from(
                request.attributes,
              );

              // Make sure 1048 is inside values, not at top level
              if (updatedAttributes.containsKey('attribute_1048')) {
                updatedAttributes.remove('attribute_1048');
                print('   🗑️ Removed top-level attribute_1048 key');
              }
              if (updatedAttributes.containsKey('values')) {
                final values =
                    updatedAttributes['values'] as Map<String, dynamic>;
                if (!values.containsKey('1048')) {
                  values['1048'] = true;
                  print('   ✅ Ensured 1048 is in values');
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
          print('❌ Address search failed: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка поиска адреса: $e')));
          setState(() => _isPublishing = false);
          return;
        }
      } else {
        print('⚠️ City or street not selected, address will be empty');
      }

      print('📋 Final address for request: $address');
      print('');
      print('🔍 Validating address data types:');
      print(
        '   region_id type: ${address['region_id'].runtimeType}, value: ${address['region_id']}',
      );
      print(
        '   city_id type: ${address['city_id'].runtimeType}, value: ${address['city_id']}',
      );
      print(
        '   street_id type: ${address['street_id'].runtimeType}, value: ${address['street_id']}',
      );
      print('   building_number: ${address['building_number']}');

      if (request.contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимо выбрать контактные данные')),
        );
        setState(() => _isPublishing = false);
        return;
      }

      final token = await HiveService.getUserData('token');

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
      print('════════════════════════════════════════════════════════');
      print('📋 FINAL REQUEST BEFORE API CALL:');
      print('   name: ${request.name}');
      print('   price: ${request.price}');
      print('   categoryId: ${request.categoryId}');
      print('   regionId: ${request.regionId}');
      print('   address: ${request.address}');
      print('   contacts: ${request.contacts}');
      print(
        '   attributes.value_selected: ${request.attributes['value_selected']}',
      );
      print('   attributes.values: ${request.attributes['values']}');
      print('════════════════════════════════════════════════════════');

      // VERIFY address has region_id and city_id
      if (!request.address.containsKey('region_id') ||
          request.address['region_id'] == null) {
        print('❌ ERROR: region_id is missing or null in address!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ошибка: регион не найден. Пожалуйста, выберите другой адрес',
            ),
          ),
        );
        setState(() => _isPublishing = false);
        return;
      }

      if (!request.address.containsKey('city_id') ||
          request.address['city_id'] == null) {
        print('❌ ERROR: city_id is missing or null in address!');
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

      // Step 1: Create advert WITHOUT images first
      setState(() {
        _publishingProgress = 'Отправка объявления на модерацию...';
      });

      final response = await ApiService.createAdvert(request, token: token);

      if (response['success'] != true) {
        // Hide loading
        setState(() {
          _isPublishing = false;
          _publishingProgress = '';
        });

        // Handle validation errors (422) or other errors
        String errorMessage = response['message'] ?? 'Ошибка публикации';

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
      if (response['data'] != null) {
        if (response['data'] is List && (response['data'] as List).isNotEmpty) {
          // API returns data as a list, get first item
          final data = (response['data'] as List)[0] as Map<String, dynamic>;
          advertId = data['id'] as int?;
          print('✅ Extracted advert ID from list: $advertId');
        } else if (response['data'] is Map) {
          // Alternative format: data as direct map
          final data = response['data'] as Map<String, dynamic>;
          advertId = data['id'] as int?;
          print('✅ Extracted advert ID from map: $advertId');
        }
      }

      if (advertId == null) {
        print('❌ ERROR: No advert ID returned from API!');
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

      print('✅ Advert created with ID: $advertId');

      // Step 2: Upload images if any
      if (_images.isNotEmpty) {
        try {
          setState(() {
            _publishingProgress =
                'Загрузка изображений (0/${_images.length})...';
          });

          final imagePaths = _images.map((file) => file.path).toList();
          final imageResponse = await ApiService.uploadAdvertImages(
            advertId,
            imagePaths,
            token: token,
          );

          print('✅ Images uploaded successfully!');
          print('Response: $imageResponse');
        } catch (e) {
          print('⚠️ Warning: Error uploading images: $e');
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
      print('✅ Объявление отправлено в админку');
      print('Response: ${response['message']}');

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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Объявление на модерации'),
          content: const Text(
            'Ваше объявление отправлено на модерацию. После проверки оно будет опубликовано.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
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
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
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
                      color: Color.fromARGB(255, 221, 27, 27),
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
                        ? secondaryBackground
                        : primaryBackground,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: _images.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 28.0),
                                child: Icon(
                                  Icons.add_circle_outline,
                                  color: textSecondary,
                                  size: 40,
                                ),
                              ),
                              SizedBox(height: 3),
                              Padding(
                                padding: EdgeInsets.only(bottom: 27.0),
                                child: Text(
                                  'Добавить изображение',
                                  style: TextStyle(
                                    color: textSecondary,
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
                                    borderRadius: BorderRadius.circular(5),
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
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
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
              const SizedBox(height: 13),

              _buildTextField(
                label: 'Заголовок объявления',
                hint: 'Например, уютная 2-комнатная квартира',
                controller: _titleController,
              ),
              const SizedBox(height: 7),
              Text(
                'Введите не менее 16 символов',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 15),

              _buildDropdown(
                label: 'Категория',
                hint: _categoryName.isEmpty ? 'Загрузка...' : _categoryName,
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
                minLength: 70,
                maxLength: 255,
                maxLines: 4,
                controller: _descriptionController,
              ),

              const SizedBox(height: 24),

              const Text(
                'Цена*',
                style: TextStyle(color: textPrimary, fontSize: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: textPrimary),
                              decoration: const InputDecoration(
                                hintText: '1 000 000',
                                hintStyle: TextStyle(
                                  color: textSecondary,
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
              const SizedBox(height: 15),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ...(List<Attribute>.from(_attributes)
                      ..sort((a, b) => a.order.compareTo(b.order)))
                    .where(
                      (attr) =>
                          attr.title.isNotEmpty &&
                          attr.id != 1048 &&
                          attr.id !=
                              19, // Exclude both attributes (1048 - price offer, 19 - personal/business - shown separately)
                    )
                    .map(
                      (attr) => Column(
                        children: [
                          _buildDynamicFilter(attr),
                          const SizedBox(height: 9),
                        ],
                      ),
                    )
                    .toList(),

              // ============ Special attribute 1127: Общая площадь (Total area) ============
              // This attribute is REQUIRED but not in API filters list
              const Text(
                'Общая площадь*',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 9),
              _buildAreaRangeField(),
              const SizedBox(height: 15),

              const Text(
                'Частное лицо / Бизнес*',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Частное лицо',
                    isIndividualSelected == true,
                    () => _togglePersonType(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Бизнес',
                    isIndividualSelected == false,
                    () => _togglePersonType(false),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Text(
                'Частное до 2х объявлений. Бизнес от 2х и более объявлений.',
                style: TextStyle(color: textMuted, fontSize: 11),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Автопродление',
                        style: TextStyle(color: textPrimary, fontSize: 16),
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
                      const SnackBar(content: Text('Области загружаются...')),
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
                              regionId = _regions[regionIndex]['id'] as int?;
                            }
                            setState(() {
                              _selectedRegion = selected;
                              _selectedRegionId = regionId;
                              _selectedCity.clear();
                              _selectedStreet.clear();
                              _selectedCityId = null;
                              _selectedStreetId = null;
                              _cities.clear();
                              _streets.clear();
                              _selectedBuilding.clear();
                              _selectedBuildingId = null;
                              _buildings.clear();
                            });
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
                hint: _selectedCity.isEmpty
                    ? 'Выберите город'
                    : _selectedCity.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: _selectedRegionId == null
                    ? null
                    : () async {
                        // Load cities for selected region
                        if (_cities.isEmpty && _selectedRegionId != null) {
                          try {
                            final token = await HiveService.getUserData(
                              'token',
                            );
                            // Get the region name to use as search query
                            // API requires q parameter to be at least 3 characters
                            String searchQuery = 'по'; // Default search term
                            if (_selectedRegion.isNotEmpty) {
                              final regionName = _selectedRegion.first;
                              // Ensure minimum 3 characters for API
                              if (regionName.length >= 3) {
                                // Use up to first 50 chars, but not more than length
                                searchQuery = regionName.length > 50
                                    ? regionName.substring(0, 50)
                                    : regionName;
                              } else {
                                searchQuery =
                                    regionName + '   '; // Pad to at least 3
                              }
                            }

                            final response =
                                await AddressService.searchAddresses(
                                  query: searchQuery,
                                  token: token,
                                  types: ['city'],
                                );

                            print(
                              '🔍 Поиск для области: "${_selectedRegion.isNotEmpty ? _selectedRegion.first : 'неизвестна'}" (ID: $_selectedRegionId)',
                            );
                            print('🔍 Поисковый запрос: "$searchQuery"');
                            print(
                              '🔍 API вернул ${response.data.length} результатов',
                            );

                            print('📋 City API response details:');
                            for (
                              int i = 0;
                              i < response.data.take(3).length;
                              i++
                            ) {
                              final result = response.data[i];
                              print(
                                '  City[$i]: city.id=${result.city?.id}, city.name=${result.city?.name}, main_region.id=${result.main_region?.id}, main_region.name=${result.main_region?.name}',
                              );
                            }

                            final uniqueCities =
                                <String, Map<String, dynamic>>{};
                            int filtered = 0;
                            for (int i = 0; i < response.data.length; i++) {
                              final result = response.data[i];
                              bool passed = false;
                              String reason = '';

                              // Filter by main_region on client side
                              if (result.main_region == null) {
                                reason = 'main_region is null';
                              } else if (result.main_region?.id !=
                                  _selectedRegionId) {
                                reason =
                                    'main_region.id=${result.main_region?.id}, ожидаем $_selectedRegionId';
                              } else if (result.city == null) {
                                reason = 'city is null';
                              } else {
                                // IMPORTANT: Store both main_region and region IDs from API response
                                uniqueCities[result.city!.name] = {
                                  'name': result.city!.name,
                                  'id': result.city!.id,
                                  'main_region_id': result.main_region?.id,
                                  'region_id': result.region?.id,
                                };
                                passed = true;
                              }

                              if (!passed) {
                                filtered++;
                                // Попытаемся найти название области для логирования
                                String mainRegionName =
                                    result.main_region?.name ?? 'неизвестна';
                                print(
                                  '   ❌ №${i + 1}: ${result.city?.name ?? result.full_address} - main_region="$mainRegionName" (ID: ${result.main_region?.id}), ожидается ID=$_selectedRegionId',
                                );
                              }
                            }

                            print('   ✅ Прошло фильтр: ${uniqueCities.length}');
                            print('   ❌ Отфильтровано: $filtered');

                            setState(() {
                              _cities = uniqueCities.values.toList();
                              print(
                                '📍 Загружено городов: ${_cities.length} для области ID $_selectedRegionId',
                              );
                              for (var i = 0; i < _cities.length; i++) {
                                print(
                                  '   ${i + 1}. ${_cities[i]['name']} (ID: ${_cities[i]['id']})',
                                );
                              }
                            });
                          } catch (e) {
                            print('Error loading cities: $e');
                          }
                        }

                        if (_cities.isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return CitySelectionDialog(
                                title: 'Ваш город',
                                options: _cities
                                    .map((c) => c['name'] as String)
                                    .toList(),
                                selectedOptions: _selectedCity,
                                onSelectionChanged: (Set<String> selected) {
                                  if (selected.isNotEmpty) {
                                    final selectedCityName = selected.first;
                                    final cityIndex = _cities.indexWhere(
                                      (c) => c['name'] == selectedCityName,
                                    );
                                    int? cityId;
                                    int? mainRegionId;
                                    if (cityIndex >= 0) {
                                      cityId = _cities[cityIndex]['id'] as int?;
                                      mainRegionId =
                                          _cities[cityIndex]['main_region_id']
                                              as int?;
                                    }
                                    setState(() {
                                      _selectedCity = selected;
                                      _selectedCityId = cityId;
                                      _selectedRegionId = mainRegionId;
                                      _selectedStreet.clear();
                                      _selectedStreetId = null;
                                      _streets.clear();
                                      _selectedBuilding.clear();
                                      _selectedBuildingId = null;
                                      _buildings.clear();
                                    });
                                    print('✅ City selected:');
                                    print('   Name: $selectedCityName');
                                    print('   ID: $cityId');
                                    print(
                                      '   Full _cities data: ${_cities[cityIndex]}',
                                    );
                                  }
                                },
                              );
                            },
                          );
                        }
                      },
              ),
              const SizedBox(height: 9),

              // Street field
              _buildDropdown(
                label: 'Улица*',
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
                        // Load streets for selected city
                        if (_streets.isEmpty && _selectedCityId != null) {
                          try {
                            final token = await HiveService.getUserData(
                              'token',
                            );
                            // Get the city name to use as search query
                            // API requires q parameter to be at least 3 characters
                            String searchQuery = 'ул'; // Default search term
                            if (_selectedCity.isNotEmpty) {
                              final cityName = _selectedCity.first;
                              // Ensure minimum 3 characters for API
                              if (cityName.length >= 3) {
                                // Use up to first 50 chars, but not more than length
                                searchQuery = cityName.length > 50
                                    ? cityName.substring(0, 50)
                                    : cityName;
                              } else {
                                searchQuery =
                                    cityName + '   '; // Pad to at least 3
                              }
                            }

                            final response =
                                await AddressService.searchAddresses(
                                  query: searchQuery,
                                  token: token,
                                  types: ['street'],
                                );

                            final uniqueStreets =
                                <String, Map<String, dynamic>>{};
                            for (final result in response.data) {
                              // Filter by city on client side
                              if (result.city?.id == _selectedCityId &&
                                  result.street != null) {
                                // IMPORTANT: Store both main_region and region IDs from API response
                                uniqueStreets[result.street!.name] = {
                                  'name': result.street!.name,
                                  'id': result.street!.id,
                                  'city_id': result.city!.id,
                                  'main_region_id': result.main_region?.id,
                                  'region_id': result.region?.id,
                                };
                              }
                            }

                            setState(() {
                              _streets = uniqueStreets.values.toList();
                            });
                          } catch (e) {
                            print('Error loading streets: $e');
                          }
                        }

                        if (_streets.isNotEmpty) {
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
                                    final selectedStreetName = selected.first;
                                    final streetIndex = _streets.indexWhere(
                                      (s) => s['name'] == selectedStreetName,
                                    );
                                    int? streetId;
                                    int? cityIdFromStreet;
                                    if (streetIndex >= 0) {
                                      streetId =
                                          _streets[streetIndex]['id'] as int?;
                                      cityIdFromStreet =
                                          _streets[streetIndex]['city_id']
                                              as int?;
                                    }
                                    setState(() {
                                      _selectedStreet = selected;
                                      _selectedStreetId = streetId;
                                      _selectedCityId = cityIdFromStreet;
                                      _selectedBuilding.clear();
                                      _selectedBuildingId = null;
                                      _buildings.clear();
                                    });
                                    print('✅ Street selected:');
                                    print('   Name: $selectedStreetName');
                                    print('   ID: $streetId');
                                    print(
                                      '   Full _streets data: ${_streets[streetIndex]}',
                                    );
                                  }
                                },
                              );
                            },
                          );
                        }
                      },
              ),
              const SizedBox(height: 9),

              // Building number field - простой ввод текста
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Номер дома*',
                    style: TextStyle(color: textPrimary, fontSize: 16),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _buildingController,
                    readOnly: _selectedStreetId == null,
                    enabled: _selectedStreetId != null,
                    decoration: InputDecoration(
                      hintText: _selectedStreetId == null
                          ? 'Выберите улицу'
                          : 'Введите номер дома (например: 45, 45А, 45/2)',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: _selectedStreetId == null
                          ? formBackground
                          : formBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(color: textPrimary),
                    onChanged: (value) {
                      setState(() {
                        _selectedBuilding = {value};
                      });
                    },
                  ),
                ],
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
                controller: _contactNameController,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Электронная почта',
                hint: 'AlexAlex@mail.ru',
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер телефона 1*',
                hint: '+7 949 456 65 56',
                keyboardType: TextInputType.phone,
                controller: _phone1Controller,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер телефона 2',
                hint: '+7 949 456 65 56',
                keyboardType: TextInputType.phone,
                controller: _phone2Controller,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш чат в телеграм',
                hint: 'https://t.me/Namename',
                controller: _telegramController,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш whatsapp',
                hint: 'https://whatsapp/Namename',
                controller: _whatsappController,
              ),

              const SizedBox(height: 22),

              // ============ Special attribute: "Вам предложат цену" ============
              // СКРЫТО НА ЭКРАНЕ - логика отправки остается в _collectFormData()
              // и _publishAdvert(), но UI не отображается
              // GestureDetector и checkbox для 1048 удалены из build()
              _buildButton(
                'Предпросмотр',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PublicationTariffScreen(),
                    ),
                  );
                },
                isPrimary: _selectedAction == 'preview',
              ),
              const SizedBox(height: 10),
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
                            const Text(
                              'Публикация объявления...',
                              style: TextStyle(color: Colors.white),
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
                  'Опубликовать',
                  onPressed: _publishAdvert,
                  isPrimary: _selectedAction == 'publish',
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    int maxLines = 1,
    int minLength = 0,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            minLines: maxLines == 1 ? 1 : maxLines,
            maxLines: null,
            maxLength: maxLength,
            keyboardType: keyboardType,
            style: const TextStyle(color: textPrimary),
            onChanged: onChanged,
            expands: false,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
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
        if (minLength > 0)
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
    VoidCallback? onTap,
    String? subtitle,
    Widget? icon,
    bool showChangeText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: const TextStyle(color: textPrimary, fontSize: 16),
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
              color: formBackground,
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
                              style: const TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
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
                          style: const TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
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
      ],
    );
  }

  Widget _buildChoiceButton(
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? activeIconColor : Colors.transparent,
          side: isSelected ? null : const BorderSide(color: Colors.white),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : textPrimary,
            fontSize: 14,
          ),
        ),
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

  Widget _buildAreaRangeField() {
    // Build special field for attribute 1127 (Total area)
    // Changed to single input field instead of range
    _selectedValues[1127] ??= '';

    final controller = _controllers.putIfAbsent(
      1127,
      () => TextEditingController(text: _selectedValues[1127] ?? ''),
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
          print('onChanged for 1127 area: $value');
          setState(() {
            _selectedValues[1127] = value;
          });
        },
      ),
    );
  }

  Widget _buildDynamicFilter(Attribute attr) {
    // Render based on style from API
    switch (attr.style) {
      case 'B':
        // Style B: Чекбокс (single value checkbox)
        return _buildCheckboxField(attr);

      case 'C':
        // Style C: Специальный дизайн (buttons for yes/no)
        return _buildSpecialDesignField(attr);

      case 'D':
        // Style D: Множественный выбор (dropdown list for multiple)
        return _buildMultipleSelectDropdown(attr);

      case 'E':
        // Style E: Диапазон целых чисел (range with integers)
        return _buildRangeField(attr, isInteger: true);

      case 'F':
        // Style F: Множественный выбор (modal/popup selection)
        return _buildMultipleSelectPopup(attr);

      case 'G':
        // Style G: Диапазон чисел (range with decimals)
        return _buildRangeField(attr, isInteger: false);

      case 'H':
        // Style H: Текстовое поле (text input)
        return _buildTextInputField(attr);

      case 'I':
        // Style I: Скрытое поле (hidden checkbox without title)
        return _buildHiddenCheckboxField(attr);

      default:
        // Fallback for unknown styles
        if (attr.values.isNotEmpty) {
          return _buildMultipleSelectPopup(attr);
        } else if (attr.isRange) {
          return _buildRangeField(attr, isInteger: attr.dataType == 'integer');
        } else {
          return _buildTextInputField(attr);
        }
    }
  }

  // Style B: Single checkbox
  Widget _buildCheckboxField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? false;
    bool selected = _selectedValues[attr.id] is bool
        ? _selectedValues[attr.id]
        : false;
    return GestureDetector(
      onTap: () => setState(() => _selectedValues[attr.id] = !selected),
      child: Row(
        children: [
          Expanded(
            child: Text(
              attr.title,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
          CustomCheckbox(
            value: selected,
            onChanged: (v) => setState(() => _selectedValues[attr.id] = v),
          ),
        ],
      ),
    );
  }

  // Style C: Special design (buttons)
  Widget _buildSpecialDesignField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';
    String selected = _selectedValues[attr.id] is String
        ? _selectedValues[attr.id]
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!attr.isTitleHidden)
          Text(
            attr.title + (attr.isRequired ? '*' : ''),
            style: const TextStyle(color: textPrimary, fontSize: 16),
          ),
        const SizedBox(height: 12),
        if (attr.values.length == 2)
          Row(
            children: [
              _buildChoiceButton(
                attr.values[0].value,
                selected == attr.values[0].value,
                () => setState(
                  () => _selectedValues[attr.id] = attr.values[0].value,
                ),
              ),
              const SizedBox(width: 10),
              _buildChoiceButton(
                attr.values[1].value,
                selected == attr.values[1].value,
                () => setState(
                  () => _selectedValues[attr.id] = attr.values[1].value,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // Style D: Multiple select (dropdown)
  Widget _buildMultipleSelectDropdown(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    return _buildDropdown(
      label: attr.isTitleHidden
          ? ''
          : attr.title + (attr.isRequired ? '*' : ''),
      hint: selected.isEmpty ? 'Выбрать' : selected.join(', '),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return SelectionDialog(
              title: attr.title,
              options: attr.values.map((v) => v.value).toList(),
              selectedOptions: selected,
              onSelectionChanged: (Set<String> newSelected) {
                setState(() {
                  _selectedValues[attr.id] = newSelected;
                });
              },
              allowMultipleSelection: attr.isMultiple,
            );
          },
        );
      },
    );
  }

  // Style E & G: Range fields (E for integer, G for decimal)
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controllerMin,
                  keyboardType: isInteger
                      ? TextInputType.number
                      : TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'От',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      range['min'] = value;
                      _selectedValues[attr.id] = range;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: controllerMax,
                  keyboardType: isInteger
                      ? TextInputType.number
                      : TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'До',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      range['max'] = value;
                      _selectedValues[attr.id] = range;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Style F: Multiple select (popup/modal)
  Widget _buildMultipleSelectPopup(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? <String>{};
    Set<String> selected = _selectedValues[attr.id] is Set
        ? (_selectedValues[attr.id] as Set).cast<String>()
        : <String>{};

    return _buildDropdown(
      label: attr.isTitleHidden
          ? ''
          : attr.title + (attr.isRequired ? '*' : ''),
      hint: selected.isEmpty ? 'Выбрать' : selected.join(', '),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return SelectionDialog(
              title: attr.title,
              options: attr.values.map((v) => v.value).toList(),
              selectedOptions: selected,
              onSelectionChanged: (Set<String> newSelected) {
                setState(() {
                  _selectedValues[attr.id] = newSelected;
                });
              },
              allowMultipleSelection: attr.isMultiple,
            );
          },
        );
      },
    );
  }

  // Style H: Text input field
  Widget _buildTextInputField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';
    final controller = _controllers.putIfAbsent(attr.id, () {
      final value = _selectedValues[attr.id];
      final textValue = value is String ? value : (value?.toString() ?? '');
      return TextEditingController(text: textValue);
    });

    return _buildTextField(
      label: attr.isTitleHidden
          ? ''
          : attr.title + (attr.isRequired ? '*' : ''),
      hint: attr.dataType == 'integer' ? 'Цифрами' : 'Текст',
      keyboardType: attr.dataType == 'integer'
          ? TextInputType.number
          : TextInputType.text,
      controller: controller,
      onChanged: (value) => _selectedValues[attr.id] = value.trim(),
    );
  }

  // Style I: Hidden checkbox (no title)
  Widget _buildHiddenCheckboxField(Attribute attr) {
    _selectedValues[attr.id] = _selectedValues[attr.id] ?? false;
    bool selected = _selectedValues[attr.id] is bool
        ? _selectedValues[attr.id]
        : false;

    return Row(
      children: [
        Expanded(
          child: Text(
            attr.values.isNotEmpty ? attr.values[0].value : attr.title,
            style: const TextStyle(color: textPrimary, fontSize: 14),
          ),
        ),
        CustomCheckbox(
          value: selected,
          onChanged: (v) => setState(() => _selectedValues[attr.id] = v),
        ),
      ],
    );
  }
}
