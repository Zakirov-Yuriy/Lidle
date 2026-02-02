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
    _loadAttributes();
    _loadUserContacts();
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
      if (mounted) {
        setState(() {
          _attributes = response.filters;
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
      if (token == null) return;

      // Load phones
      final phonesResponse = await ApiService.get(
        '/me/settings/phones',
        token: token,
      );
      if (phonesResponse['success'] == true) {
        _userPhones = List<Map<String, dynamic>>.from(phonesResponse['data']);
      }

      // Load emails
      final emailsResponse = await ApiService.get(
        '/me/settings/emails',
        token: token,
      );
      if (emailsResponse['success'] == true) {
        _userEmails = List<Map<String, dynamic>>.from(emailsResponse['data']);
      }

      // Load telegrams
      final telegramsResponse = await ApiService.get(
        '/me/settings/telegrams',
        token: token,
      );
      if (telegramsResponse['success'] == true) {
        _userTelegrams = List<Map<String, dynamic>>.from(
          telegramsResponse['data'],
        );
      }

      // Load whatsapps
      final whatsappsResponse = await ApiService.get(
        '/me/settings/whatsapps',
        token: token,
      );
      if (whatsappsResponse['success'] == true) {
        _userWhatsapps = List<Map<String, dynamic>>.from(
          whatsappsResponse['data'],
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading user contacts: $e');
    }
  }

  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};

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

    _selectedValues.forEach((key, value) {
      final attr = _attributes.firstWhere(
        (a) => a.id == key,
        orElse: () => Attribute(id: 0, title: '', order: 0, values: []),
      );
      if (attr.id == 0) return;

      if (value is Set<String>) {
        // Multiple selection - add values_id
        for (final val in value) {
          final attrValue = attr.values.firstWhere(
            (v) => v.value == val,
            orElse: () => const Value(id: 0, value: ''),
          );
          if (attrValue.id != 0) {
            attributes['value_selected'].add(attrValue.id);
          }
        }
      } else if (value is Map) {
        // Range values
        final minVal = (value['min']?.toString() ?? '').trim();
        final maxVal = (value['max']?.toString() ?? '').trim();
        print('For attr $key, minVal: "$minVal", maxVal: "$maxVal"');
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
        final attrObj = {};
        if (parsedValue != null) {
          attrObj['value'] = parsedValue;
        }
        if (parsedMaxValue != null) {
          attrObj['max_value'] = parsedMaxValue;
        }
        if (attrObj.isNotEmpty) {
          attributes['values']['$key'] = attrObj;
        }
      } else if (value is String) {
        if (attr.values.isEmpty) {
          // Text field
          if (value.isNotEmpty) {
            attributes['values']['$key'] = {'value': value};
          }
        } else {
          // Single selection
          final attrValue = attr.values.firstWhere(
            (v) => v.value == value,
            orElse: () => const Value(id: 0, value: ''),
          );
          if (attrValue.id != 0) {
            attributes['value_selected'].add(attrValue.id);
          }
        }
      } else if (value is bool && value) {
        // Checkbox
        if (attr.values.isNotEmpty) {
          attributes['value_selected'].add(attr.values.first.id);
        }
      }
    });

    print('Collected attributes: $attributes');

    // Collect address
    final Map<String, dynamic> address = {};
    if (_selectedCity.isNotEmpty) {
      // For simplicity, assuming region_id = 13 for Mariupol
      address['region_id'] = 13;
      address['city_id'] = 70; // Mariupol city ID
    } else {
      // Default values if not selected
      address['region_id'] = 13;
      address['city_id'] = 70;
    }
    if (_selectedStreet.isNotEmpty) {
      // For simplicity, assuming a street ID
      address['street_id'] = 9199; // Example street ID
    } else {
      address['street_id'] = 9199;
    }

    // Collect contacts
    final Map<String, dynamic> contacts = {};
    if (_phone1Controller.text.isNotEmpty && _userPhones.isNotEmpty) {
      contacts['user_phone_id'] = _userPhones.first['id'];
    }
    if (_emailController.text.isNotEmpty && _userEmails.isNotEmpty) {
      contacts['user_email_id'] = _userEmails.first['id'];
    }
    if (_telegramController.text.isNotEmpty && _userTelegrams.isNotEmpty) {
      contacts['user_telegram_id'] = _userTelegrams.first['id'];
    }
    if (_whatsappController.text.isNotEmpty && _userWhatsapps.isNotEmpty) {
      contacts['user_whatsapp_id'] = _userWhatsapps.first['id'];
    }

    return CreateAdvertRequest(
      name: _titleController.text,
      description: _descriptionController.text,
      price: _priceController.text,
      categoryId: widget.category?.id ?? 2,
      regionId: 1, // Default region
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
      if (_userPhones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Необходимо добавить телефон в настройках профиля',
            ),
            action: SnackBarAction(
              label: 'Настройки',
              onPressed: () {
                // TODO: Navigate to profile settings
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
      if (!isValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
        return;
      }

      final request = _collectFormData();

      if (request.contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимо выбрать контактные данные')),
        );
        return;
      }

      final token = await HiveService.getUserData('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимо авторизоваться')),
        );
        return;
      }

      // Show loading
      setState(() => _isLoading = true);

      final response = await ApiService.createAdvert(request, token: token);

      // Hide loading
      setState(() => _isLoading = false);

      if (response['success'] == true) {
        // Log to console
        print('Объявление отправлено в админку');

        // Show moderation dialog
        _showModerationDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Ошибка публикации')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
                height: 149,
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
                      (attr) => attr.title.isNotEmpty && !attr.isTitleHidden,
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

              const SizedBox(height: 12),

              const Text(
                'Частное лицо / Бизнес*',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Частное лицо',
                    isIndividualSelected,
                    () => _togglePersonType(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Бизнес',
                    !isIndividualSelected,
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

              const SizedBox(height: 18),

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
    double height = 45,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            style: const TextStyle(color: textPrimary),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color.fromARGB(255, 255, 255, 255),
                fontSize: 14,
              ),
              filled: true,
              fillColor: formBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
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

  Widget _buildDynamicFilter(Attribute attr) {
    if (attr.isSpecialDesign) {
      if (attr.values.length == 2) {
        // Buttons for Yes/No like "Меблированная" - one always selected
        _selectedValues[attr.id] =
            _selectedValues[attr.id] ?? attr.values[0].value;
        String selected = _selectedValues[attr.id];
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
        bool selected = _selectedValues[attr.id];
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
        Set<String> selected = _selectedValues[attr.id];
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
        String selected = _selectedValues[attr.id];
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
        Map<String, String> range = Map<String, String>.from(
          _selectedValues[attr.id],
        );
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
        final controller = _controllers.putIfAbsent(
          attr.id,
          () => TextEditingController(text: _selectedValues[attr.id]),
        );
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
