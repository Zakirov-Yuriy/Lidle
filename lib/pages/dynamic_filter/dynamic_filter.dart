import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/street_selection_dialog.dart';
import '../../../constants.dart';
import '../../../services/api_service.dart';
import '../../../models/filter_models.dart';
import '../../../hive_service.dart';

// ============================================================
// "Виджет: Экран добавления аренды квартиры в недвижимость"
// ============================================================
class DynamicFilter extends StatefulWidget {
  static const String routeName = '/add-real-estate-apt';

  const DynamicFilter({super.key});

  @override
  State<DynamicFilter> createState() =>
      _DynamicFilterState();
}

// ============================================================
// "Класс состояния: Управление состоянием экрана аренды квартиры"
// ============================================================
class _DynamicFilterState
    extends State<DynamicFilter> {
  List<Attribute> _attributes = [];
  Map<int, dynamic> _selectedValues = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttributes();
  }

  Future<void> _loadAttributes() async {
    try {
      final token = HiveService.getUserData('token') as String?;
      print('Loading attributes with token: ${token != null ? 'present' : 'null'}');
      final attributes = await ApiService.getAdvertCreationAttributes(categoryId: 2, token: token);
      print('Loaded ${attributes.length} attributes');
      setState(() {
        _attributes = attributes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading attributes from API: $e');
      // Fallback to local file
      try {
        final jsonString = await rootBundle.rootBundle.loadString('assets/test_data.json');
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final List<dynamic> attributesJson = data['data']['attributes'];
        final attributes = attributesJson.map((json) => Attribute.fromJson(json as Map<String, dynamic>)).toList();
        print('Loaded ${attributes.length} attributes from local file');
        setState(() {
          _attributes = attributes;
          _isLoading = false;
        });
      } catch (fallbackError) {
        print('Error loading local data: $fallbackError');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Set<String> _selectedHouseTypes = {};
  Set<String> _selectedDealTypes = {};
  Set<String> _selectedWallTypes = {};
  Set<String> _selectedHousingClassTypes = {};
  Set<String> _selectedHeatingTypes = {};
  Set<String> _selectedCommunicationTypes =
      {};
  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};
  Set<String> _selectedRoomCounts = {};
  Set<String> _selectedLayoutTypes = {};
  Set<String> _selectedBathroomTypes = {};
  Set<String> _selectedRenovationTypes = {};
  Set<String> _selectedAppliancesTypes = {};
  Set<String> _selectedMultimediaTypes = {};

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
  bool? _selectedFurnished =
      true; 


  String _selectedAction = 'publish'; 

  void _togglePersonType(bool isIndividual) {
    setState(() => isIndividualSelected = isIndividual);
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
                    child: const Icon(Icons.close, color: Color.fromARGB(255, 221, 27, 27)),
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
                    color: _images.isEmpty ? secondaryBackground : primaryBackground,
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
                                onTap: () => _showImageSourceActionSheet(context),
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
                                          borderRadius: BorderRadius.circular(5),
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
              ),
              const SizedBox(height: 7),
              Text(
                'Введите не менее 16 символов',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 15),

              _buildDropdown(
                label: 'Категория',
                hint: 'Долгосрочная аренда комнат',
                subtitle: 'Недвижимость',
                onTap: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) =>
                  //         const RealEstateSubcategoriesScreen(),
                  //   ),
                  // );
                },
                showChangeText: true,
              ),
              const SizedBox(height: 13),

              _buildTextField(
                label: 'Описание',
                hint:
                    'Чем больше информации вы укажете о вашей квартире, тем привлекательнее она будет для покупателей. Без ссылок, телефонов, матершинных слов.',
                minLength: 70,
                maxLines: 4,
                height: 149,
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
                ...(_attributes.where((attr) => attr.isFilter).toList()..sort((a, b) => a.order.compareTo(b.order))).map((attr) => Column(
                  children: [
                    _buildDynamicFilter(attr),
                    const SizedBox(height: 9),
                  ],
                )).toList(),

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

              _buildTextField(label: 'Номер дома*', hint: 'Номер дома'),
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

              _buildTextField(label: 'Контактное лицо*', hint: 'Александр'),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Электронная почта',
                hint: 'AlexAlex@mail.ru',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер телефона 1*',
                hint: '+7 949 456 65 56',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Номер телефона 2',
                hint: '+7 949 456 65 56',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш чат в телеграм',
                hint: 'https://t.me/Namename',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш whatsapp',
                hint: 'https://whatsapp/Namename',
              ),

              const SizedBox(height: 22),

              _buildButton(
                'Предпросмотр',
                onPressed: () {
                  setState(() {
                    _selectedAction = 'preview';
                  });
                },
                isPrimary: _selectedAction == 'preview',
              ),
              const SizedBox(height: 10),
              _buildButton(
                'Опубликовать',
                onPressed: () {
                  // setState(() {
                  //   _selectedAction = 'publish';
                  // });
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const PublicationTariffScreen(),
                  //   ),
                  // );
                },
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
    TextInputType keyboardType = TextInputType.text,
    double height = 45,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: TextField(
            minLines: 1,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: textPrimary),
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
          child: Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
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
                    style: TextStyle(
                      color: Colors.blue, 
                      fontSize: 14, 
                    ),
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
        _selectedValues[attr.id] = _selectedValues[attr.id] ?? attr.values[0].value;
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
                  () => setState(() => _selectedValues[attr.id] = attr.values[0].value),
                ),
                const SizedBox(width: 10),
                _buildChoiceButton(
                  attr.values[1].value,
                  selected == attr.values[1].value,
                  () => setState(() => _selectedValues[attr.id] = attr.values[1].value),
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
                onChanged: (v) => setState(() => _selectedValues[attr.id] = v ?? false),
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
          label: attr.isTitleHidden ? '' : attr.title + (attr.isRequired ? '*' : ''),
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
        _selectedValues[attr.id] = _selectedValues[attr.id] ?? '';
        String selected = _selectedValues[attr.id];
        return _buildDropdown(
          label: attr.isTitleHidden ? '' : attr.title + (attr.isRequired ? '*' : ''),
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
                      _selectedValues[attr.id] = newSelected.isNotEmpty ? newSelected.first : '';
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
      if (attr.isRange) {
        _selectedValues[attr.id] = _selectedValues[attr.id] ?? {'min': '', 'max': ''};
        Map<String, String> range = Map<String, String>.from(_selectedValues[attr.id]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attr.isTitleHidden ? '' : attr.title + (attr.isRequired ? '*' : ''),
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
                      keyboardType: attr.dataType == 'integer' ? TextInputType.number : TextInputType.text,
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
                        range['min'] = value;
                        _selectedValues[attr.id] = range;
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
                      keyboardType: attr.dataType == 'integer' ? TextInputType.number : TextInputType.text,
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
                        range['max'] = value;
                        _selectedValues[attr.id] = range;
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
        return _buildTextField(
          label: attr.isTitleHidden ? '' : attr.title + (attr.isRequired ? '*' : ''),
          hint: attr.dataType == 'integer' ? 'Цифрами' : 'Текст',
          keyboardType: attr.dataType == 'integer' ? TextInputType.number : TextInputType.text,
        );
      }
    }
  }
}
