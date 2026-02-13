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
import '../../../services/user_service.dart';
import '../../../models/filter_models.dart';
import '../../../models/catalog_model.dart';
import '../../../models/create_advert_model.dart';
import '../../../hive_service.dart';
import 'package:lidle/pages/add_listing/real_estate_subcategories_screen.dart';
import 'package:lidle/pages/add_listing/publication_tariff_screen.dart';

// ============================================================
// "Виджет: Экран добавления аренды квартиры в недвижимость"
// ============================================================
class DynamicFilter extends StatefulWidget {
  static const String routeName = '/add-real-estate-apt';

  final Category? category;

  const DynamicFilter({super.key, this.category});

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

  @override
  void initState() {
    super.initState();
    // Initialize attribute 1048 (Вам предложат цену) to true by default
    _selectedValues[1048] = true;

    _loadAttributes();
    _loadUserContacts();
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
      print('Loading filters for category: ${widget.category?.id ?? 2}');
      final token = await HiveService.getUserData('token');
      final response = await ApiService.getMetaFilters(
        categoryId: widget.category?.id ?? 2,
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

    print('🧪 AUTO-FILLING FORM FOR TESTING...');

    setState(() {
      // Основные поля объявления
      _titleController.text = 'Просторная однокомнатная квартира';
      _descriptionController.text =
          'Комфортная однокомнатная квартира площадью 45 кв.м, расположена в тихом районе с хорошей инфраструктурой. Полностью меблирована, есть все необходимое для жизни.';
      _priceController.text = '120000';

      // Контакты - только если они ещё не загружены из API
      // (Если они уже заполнены из API, не перезаписываем)
      if (_contactNameController.text.isEmpty) {
        _contactNameController.text = 'Юрий1 ';
      }
      if (_emailController.text.isEmpty) {
        _emailController.text = '1workyury02@gmail.com';
      }
      if (_phone1Controller.text.isEmpty) {
        _phone1Controller.text = '+79254499552';
      }

      // Выбор контактов из загруженных
      if (_userPhones.isNotEmpty) {
        print('✅ Selected first phone: ${_userPhones[0]['phone']}');
      }
      if (_userEmails.isNotEmpty) {
        print('✅ Selected first email: ${_userEmails[0]['email']}');
      }

      // Автозаполнение атрибутов фильтров
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

      // Select city and street for address
      // Using valid examples from backend: г. Ждановка (city_id=70), кв-л 28/33 (street_id=9199)
      _selectedCity = {'г. Ждановка'}; // city_id from API
      _selectedStreet = {'кв-л 28/33'}; // street_id from API

      // Auto-fill building number
      _buildingController.text = 'д. 15А';

      print('🧪 Auto-fill completed:');
      print('   Title: ${_titleController.text}');
      print('   City: ${_selectedCity.first}');
      print('   Street: ${_selectedStreet.first}');
      print('   Building: ${_buildingController.text}');
      print('   Price: ${_priceController.text}');
      print('   Selected values: $_selectedValues');
    });
  }

  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};
  int? mainRegionId = 1; // Track main_region.id for top-level region_id

  // Хранилище ID адресов полученных из API /addresses/search
  Map<String, dynamic>?
  _currentAddressData; // Full address data from API search

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

  bool isIndividualSelected = true;
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
    setState(() => isIndividualSelected = isIndividual);
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
      categoryId: widget.category?.id ?? 2,
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
            print('📍 Step 1: Searching for city: ${_selectedCity.first}');
            print('   Query params: q="${_selectedCity.first}", types[]=city');
            var cityId;
            try {
              final cityResults = await ApiService.searchAddresses(
                _selectedCity.first,
                token: token,
                types: ['city'],
                // NO filters - API will return city with region_id
              );

              if (cityResults.isNotEmpty) {
                final firstResult = cityResults.first;
                // API returns nested structure: {'city': {'id': ..., 'name': ...}, 'region': {...}, ...}
                cityId = firstResult['city']?['id'] ?? firstResult['id'];

                // Extract region_id from the response
                final regionId = firstResult['region']?['id'];
                if (regionId != null) {
                  address['region_id'] = regionId;
                  print('   ✅ Found region_id=$regionId');
                }

                address['city_id'] = cityId;
                print('   ✅ Found city_id=$cityId');
                print('   Full response: ${firstResult['full_address']}');
              } else {
                throw Exception('City not found: ${_selectedCity.first}');
              }
            } catch (e) {
              print('   ❌ City search failed: $e');
              throw e;
            }

            // ============ STEP 2: Search for street with city_id filter ============
            print('📍 Step 2: Searching for street: ${_selectedStreet.first}');
            print(
              '   Query params: q="${_selectedStreet.first}", types[]=street, filters[city_id]=$cityId',
            );
            var streetId;
            try {
              final streetResults = await ApiService.searchAddresses(
                _selectedStreet.first,
                token: token,
                types: ['street'],
                filters: {'city_id': cityId},
              );

              if (streetResults.isNotEmpty) {
                final firstResult = streetResults.first;
                streetId = firstResult['street']?['id'] ?? firstResult['id'];
                address['street_id'] = streetId;
                print('   ✅ Found street_id=$streetId');
              } else {
                throw Exception('Street not found: ${_selectedStreet.first}');
              }
            } catch (e) {
              print('   ❌ Street search failed: $e');
              throw e;
            }

            // ============ STEP 3: Remove main_region_id (API doesn't accept it) ============
            // API expects only: region_id, city_id, street_id
            // Remove main_region_id if it was added
            if (address.containsKey('main_region_id')) {
              address.remove('main_region_id');
              print('   🗑️ Removed main_region_id (API rejects it)');
            }

            print('✅ Address search completed:');
            print('   region_id: ${address['region_id']}');
            print('   city_id: ${address['city_id']}');
            print('   street_id: ${address['street_id']}');

            // Recreate request with address from API search
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
                hint: widget.category?.name ?? 'Долгосрочная аренда комнат',
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
                                  color: Color.fromARGB(255, 255, 255, 255),
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
                          attr.id !=
                              1048, // Exclude "Вам предложат цену" - it's shown separately
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
              // const SizedBox(height: 15),

              // const SizedBox(height: 12),

              // const Text(
              //   'Частное лицо / Бизнес*',
              //   style: TextStyle(color: textPrimary, fontSize: 14),
              // ),
              // const SizedBox(height: 12),
              // Row(
              //   children: [
              //     _buildChoiceButton(
              //       'Частное лицо',
              //       isIndividualSelected,
              //       () => _togglePersonType(true),
              //     ),
              //     const SizedBox(width: 10),
              //     _buildChoiceButton(
              //       'Бизнес',
              //       !isIndividualSelected,
              //       () => _togglePersonType(false),
              //     ),
              //   ],
              // ),

              // const SizedBox(height: 12),
              // const Text(
              //   'Частное до 2х объявлений. Бизнес от 2х и более объявлений.',
              //   style: TextStyle(color: textMuted, fontSize: 11),
              // ),
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

              // const SizedBox(height: 18),
              _buildDropdown(
                label: 'Ваш город*',
                hint: _selectedCity.isEmpty
                    ? 'Ваш город'
                    : _selectedCity.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return CitySelectionDialog(
                        title: 'Ваш город',
                        options: const [
                          'Абаза',
                          'Абакан',
                          'Абдулино',
                          'Абинск',
                          'Агидель',
                          'Агрыз',
                          'Адыгейск',
                          'Азнакаево',
                          'Бабаево',
                          'Бабушкин Бавлы',
                          'Багратионовск',
                        ],
                        selectedOptions: _selectedCity,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedCity = selected;
                          });
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Улица*',
                hint: _selectedStreet.isEmpty
                    ? 'Ваша улица'
                    : _selectedStreet.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return StreetSelectionDialog(
                        title: 'Улица',
                        groupedOptions: const {
                          'Центральный район': [
                            'Аэродромная улица',
                            'Бахмутская улица',
                            'бул. Богдана Хмельницкого',
                            'бул. Шевченко Георгиевская',
                            'ул. Гранитная улица Греческая',
                            'ул. Евпаторийская улица',
                            'ул. Заводская',
                            'Запорожское шоссе',
                          ],
                          'Приморский район': [
                            'ул. Амурская',
                            'Бердянский переулок',
                            'ул. Большая Азовская',
                          ],
                        },
                        selectedOptions: _selectedStreet,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedStreet = selected;
                          });
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер дома*',
                hint: 'Номер дома',
                controller: _buildingController,
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
              hintStyle: const TextStyle(
                color: Color.fromARGB(255, 255, 255, 255),
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
          hintStyle: TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 14,
          ),
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
    if (attr.isSpecialDesign) {
      if (attr.values.length == 2) {
        // Buttons for Yes/No like "Меблированная" - one always selected
        _selectedValues[attr.id] =
            _selectedValues[attr.id] ?? attr.values[0].value;
        var selectedValue = _selectedValues[attr.id];
        String selected = selectedValue is String
            ? selectedValue
            : selectedValue.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!attr.isTitleHidden)
              Text(
                attr.title + (attr.isRequired ? '*' : ''),
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
            const SizedBox(height: 12),
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
      } else {
        // Checkbox for single value like "Возможен торг"
        _selectedValues[attr.id] = _selectedValues[attr.id] ?? false;
        var selectedValue = _selectedValues[attr.id];
        bool selected = selectedValue is bool ? selectedValue : false;
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
    } else if (attr.values.isNotEmpty) {
      if (attr.isMultiple) {
        _selectedValues[attr.id] = _selectedValues[attr.id] ?? <String>{};
        var selectedValue = _selectedValues[attr.id];
        Set<String> selected;
        if (selectedValue is Set) {
          selected = selectedValue.cast<String>();
        } else {
          selected = <String>{};
        }
        return _buildDropdown(
          label: attr.isTitleHidden
              ? ''
              : attr.title + (attr.isRequired ? '*' : ''),
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
                  title: attr.title,
                  options: attr.values.map((v) => v.value).toList(),
                  selectedOptions: selected,
                  onSelectionChanged: (Set<String> newSelected) {
                    setState(() {
                      _selectedValues[attr.id] = newSelected;
                    });
                  },
                  allowMultipleSelection: true,
                );
              },
            );
          },
        );
      } else {
        _selectedValues[attr.id] =
            _selectedValues[attr.id] ??
            (attr.isRequired && attr.values.isNotEmpty
                ? attr.values.first.value
                : '');
        var selectedValue = _selectedValues[attr.id];
        String selected = selectedValue is String
            ? selectedValue
            : selectedValue.toString();
        return _buildDropdown(
          label: attr.isTitleHidden
              ? ''
              : attr.title + (attr.isRequired ? '*' : ''),
          hint: selected.isEmpty ? 'Выбрать' : selected,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textSecondary,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SelectionDialog(
                  title: attr.title,
                  options: attr.values.map((v) => v.value).toList(),
                  selectedOptions: {selected},
                  onSelectionChanged: (Set<String> newSelected) {
                    setState(() {
                      _selectedValues[attr.id] = newSelected.isNotEmpty
                          ? newSelected.first
                          : (attr.isRequired && attr.values.isNotEmpty
                                ? attr.values.first.value
                                : '');
                    });
                  },
                  allowMultipleSelection: false,
                );
              },
            );
          },
        );
      }
    } else {
      // Special case for floor attribute (id 1040) and area (id 1037) - always show as range
      if (attr.isRange || attr.id == 1040 || attr.id == 1037) {
        _selectedValues[attr.id] ??= {'min': '', 'max': ''};
        var rawValue = _selectedValues[attr.id];

        // Ensure it's a proper map
        Map<String, dynamic> rangeMap;
        if (rawValue is Map) {
          rangeMap = rawValue as Map<String, dynamic>;
        } else {
          rangeMap = {'min': '', 'max': ''};
        }

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
            Text(
              attr.isTitleHidden
                  ? ''
                  : attr.title + (attr.isRequired ? '*' : ''),
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
                      keyboardType: attr.dataType == 'integer'
                          ? TextInputType.number
                          : (attr.dataType == 'numeric'
                                ? TextInputType.numberWithOptions(decimal: true)
                                : TextInputType.text),
                      style: const TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'От',
                        hintStyle: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        print('onChanged for ${attr.id} min: $value');
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
                      keyboardType: attr.dataType == 'integer'
                          ? TextInputType.number
                          : (attr.dataType == 'numeric'
                                ? TextInputType.numberWithOptions(decimal: true)
                                : TextInputType.text),
                      style: const TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'До',
                        hintStyle: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 14,
                        ),
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
      } else {
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
    }
  }
}
