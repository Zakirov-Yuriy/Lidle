import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lidle/pages/create_listing_screen.dart';
import 'package:lidle/pages/real_estate_subcategories_screen.dart';
import 'package:lidle/widgets/%D1%81ustom_witch.dart';
import 'package:lidle/widgets/custom_checkbox.dart';
import 'package:lidle/widgets/selection_dialog.dart';
import 'package:lidle/widgets/city_selection_dialog.dart'; // Import the new city selection dialog
import 'package:lidle/widgets/street_selection_dialog.dart'; // Import the new street selection dialog
import 'package:lidle/pages/publication_tariff_screen.dart'; // Import the new publication tariff screen

import '../constants.dart';

class AddRealEstateAptScreen extends StatefulWidget {
  static const String routeName = '/add-real-estate-apt';

  const AddRealEstateAptScreen({super.key});

  @override
  State<AddRealEstateAptScreen> createState() => _AddRealEstateAptScreenState();
}

class _AddRealEstateAptScreenState extends State<AddRealEstateAptScreen> {
  Set<String> _selectedHouseTypes = {};
  Set<String> _selectedDealTypes = {};
  Set<String> _selectedWallTypes = {};
  Set<String> _selectedHousingClassTypes = {};
  Set<String> _selectedHeatingTypes = {}; // New state for Heating filter
  Set<String> _selectedCommunicationTypes = {}; // New state for Communications filter
  Set<String> _selectedCity = {}; // New state for selected city
  Set<String> _selectedStreet = {}; // New state for selected street
  Set<String> _selectedRoomCounts = {}; // New state for Room Count filter
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateListingScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],          ),
        );
      },
    );
  }

  // Переключатели
  bool isIndividualSelected = true; // Частное лицо / Бизнес
  bool isSecondarySelected = true; // Вторичка / Новостройка
  bool isMortgageYes = true; // Ипотека Да / Нет

  // Чекбоксы цены
  bool isBargain = false; // Возможен торг
  bool isNoCommission = false; // Без комиссии
  bool isExchange = false; // Возможность обмена
  bool isPledge = false; // Готов принять в залог
  bool isUrgent = false; // Срочно
  bool isInstallment = false; // Рассрочка
  bool isRemoteDeal = false; // Удалённая сделка
  bool isClientPrice = false; // Клиент может предложить свою цену
  bool isAutoRenewal = false; // Автопродление
  bool isAutoRenewal1 = false;

  void _togglePersonType(bool isIndividual) {
    setState(() => isIndividualSelected = isIndividual);
  }

  void _toggleMarketType(bool isSecondary) {
    setState(() => isSecondarySelected = isSecondary);
  }

  void _toggleMortgage(bool yes) {
    setState(() => isMortgageYes = yes);
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
              

              // Заголовок
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: textPrimary),
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

              // Блок "Опишите товар или услугу"
              const Text(
                'Опишите товар или услугу',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 17),

              // Добавить изображение
              GestureDetector(
                onTap: () {
                  _showImageSourceActionSheet(context);
                },
                child: Container(
                  height: 118,
                  decoration: BoxDecoration(
                    color: secondaryBackground,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: _images.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: textSecondary,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Добавить изображение',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            return Image.file(
                              _images[index],
                              fit: BoxFit.cover,
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
                hint: 'Продажа квартир',
                subtitle: 'Недвижимость / Квартиры',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const RealEstateSubcategoriesScreen(),
                    ),
                  );
                },
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

              // Цена
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

              // Чекбоксы по цене
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Возможен торг',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isBargain,
                    onChanged: (v) => setState(() => isBargain = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Без комиссии',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isNoCommission,
                    onChanged: (v) => setState(() => isNoCommission = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Возможность обмена',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isExchange,
                    onChanged: (v) => setState(() => isExchange = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Готов принять в залог',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isPledge,
                    onChanged: (v) => setState(() => isPledge = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Срочно',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isUrgent,
                    onChanged: (v) => setState(() => isUrgent = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Рассрочка',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isInstallment,
                    onChanged: (v) => setState(() => isInstallment = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Удалённая сделка',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isRemoteDeal,
                    onChanged: (v) => setState(() => isRemoteDeal = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Клиент может предложить свою цену',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                  ),
                  CustomCheckbox(
                    value: isClientPrice,
                    onChanged: (v) => setState(() => isClientPrice = v),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Ипотека
              const Text(
                'Ипотека',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Да',
                    isMortgageYes,
                    () => _toggleMortgage(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Нет',
                    !isMortgageYes,
                    () => _toggleMortgage(false),
                  ),
                ],
              ),

              const SizedBox(height: 13),
              // Рассрочка
              const Text(
                'Рассрочка',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isInstallment
                            ? activeIconColor
                            : Colors.transparent,
                        side: isInstallment
                            ? null
                            : const BorderSide(color: Colors.white),
                        // padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: () => setState(() => isInstallment = true),
                      child: Text(
                        'Да',
                        style: TextStyle(
                          color: isInstallment ? Colors.white : textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !isInstallment
                            ? activeIconColor
                            : Colors.transparent,
                        side: !isInstallment
                            ? null
                            : const BorderSide(color: Colors.white),
                        // padding: const EdgeInsets.symmetric(vertical: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: () => setState(() => isInstallment = false),
                      child: Text(
                        'Нет',
                        style: TextStyle(
                          color: !isInstallment ? Colors.white : textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              // Блок характеристик квартиры
              _buildDropdown(
                label: 'Тип дома',
                hint: _selectedHouseTypes.isEmpty
                    ? 'Сталинка'
                    : _selectedHouseTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Тип дома',
                        options: const [
                          'Все объявления',
                          'Царский дом',
                          'Сталинка',
                          'Хрущевка',
                          'Чешка',
                          'Гостинка',
                          'Совмин',
                          'Общежитие',
                          'Жилой фонд 80-90-е',
                          'Жилой фонд 91-2000-е',
                          'Жилой фонд 2001-2010-е',
                          'Жилой фонд 2011-2020-е',
                          'Жилой фонд от 2021 г.',
                        ],
                        selectedOptions: _selectedHouseTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedHouseTypes = selected;
                          });
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),
              _buildTextField(
                label: 'Название ЖК',
                hint: 'Название жилого комплекса',
              ),
              const SizedBox(height: 9),

              _buildTextField(label: 'Номер квартиры', hint: 'Номер квартиры'),
              const SizedBox(height: 9),

              _buildTextField(label: 'Этаж*', hint: 'Укажите этаж'),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Этажность*',
                hint: 'Общее количество этажей',
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Тип сделки',
                hint: _selectedDealTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedDealTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Тип сделки',
                        options: const [
                          'От застройщика',
                          'Переуступка',
                          'Рассрочка от',
                          'Рассрочка от банка',
                          'Банковский кредит',
                          'Лизинг',
                        ],
                        selectedOptions: _selectedDealTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedDealTypes = selected;
                          });
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Общая площадь(м²)*',
                hint: 'Цифрами',
                
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Тип стен',
                hint: _selectedWallTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedWallTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Тип стен',
                        options: const [
                          'Газоблок',
                          'Кирпич',
                          'Панель',
                          'Монолит',
                          'Дерево',
                          'Каркасный',
                          'СИП-панель',
                        ],
                        selectedOptions: _selectedWallTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedWallTypes = selected;
                          });
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Класс жилья',
                hint: _selectedHousingClassTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedHousingClassTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Класс жилья',
                        options: const [
                          'Эконом',
                          'Комфорт',
                          'Бизнес',
                          'Премиум',
                        ],
                        selectedOptions: _selectedHousingClassTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedHousingClassTypes = selected;
                          });
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Количество комнат*',
                hint: _selectedRoomCounts.isEmpty
                    ? 'Цифрами'
                    : _selectedRoomCounts.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Количество комнат',
                        options: const [
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6+',
                        ],
                        selectedOptions: _selectedRoomCounts,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedRoomCounts = selected;
                          });
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Планировка',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Санузел',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Отопление',
                hint: _selectedHeatingTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedHeatingTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Отопление',
                        options: const [
                          'Централизованное',
                          'Собственная котельная',
                          'Индивидуальное газовое',
                          'Индивидуальное электро',
                          'Твердопливное',
                          'Тепловой насос',
                          'Комбинированное',
                          'Другое',
                        ],
                        selectedOptions: _selectedHeatingTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedHeatingTypes = selected;
                          });
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Ремонт',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 9),

              // Мебелирован
              const Text(
                'Мебелирован',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton('Да', true, () {
                    // TODO: сохранить значение
                  }),
                  const SizedBox(width: 10),
                  _buildChoiceButton('Нет', false, () {
                    // TODO: сохранить значение
                  }),
                ],
              ),
              const SizedBox(height: 18),

              _buildDropdown(
                label: 'Бытовая техника',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Мультимедиа',
                hint: 'Цифрами',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Комфорт',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Коммуникации',
                hint: _selectedCommunicationTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedCommunicationTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Коммуникации',
                        options: const [
                          'Газ',
                          'Центраный',
                          'Скважина',
                          'Электичество',
                          'Центральная',
                          'Канализация',
                          'Вывоз отходов',
                          'Без коммуникаций',
                          
                        ],
                        selectedOptions: _selectedCommunicationTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedCommunicationTypes = selected;
                          });
                        },
                        allowMultipleSelection: true, // Assuming multiple selections are allowed for communications
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              const Text(
                'Вид объекта',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Вторичка',
                    isSecondarySelected,
                    () => _toggleMarketType(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Новостройка',
                    !isSecondarySelected,
                    () => _toggleMarketType(false),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _buildTextField(
                label: 'Год постройки',
                hint: 'Укажите год',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Площадь кухни(м²)',
                hint: 'Цифрами',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Инфраструктура (до 500 метров)',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Ландшафт (до 1 км)',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
              ),

              const SizedBox(height: 27),

              // Частное лицо / Бизнес
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
              // Блок характеристик квартиры
              const Text(
                'Частное до 2х объявлений. Бизнес от 2х и более объявлений.',
                style: TextStyle(color: textMuted, fontSize: 11),
              ),

              const SizedBox(height: 18),

              // Автопродление
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
                          
                       
                          // Add more cities as needed
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

              // Контактные данные
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
                hint: 'https://t.me/username',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш whatsapp',
                hint: 'https://wa.me/номер',
              ),

              const SizedBox(height: 32),

              _buildButton('Предпросмотр', onPressed: () {}),
              const SizedBox(height: 10),
              _buildButton(
                'Опубликовать',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PublicationTariffScreen(),
                    ),
                  );
                },
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Общие билдеры (повторяем стиль AddListingScreen) ======

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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
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
          backgroundColor: isPrimary ? activeIconColor : Colors.transparent,
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
}
