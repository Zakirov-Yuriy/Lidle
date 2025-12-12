import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../real_estate_subcategories_screen.dart';
import '../publication_tariff_screen.dart';

import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/street_selection_dialog.dart';

import '../../../constants.dart';

/// ============================================================
/// Экран: Создание объявления — Продажа домов
/// ============================================================
class AddHouseRentScreen extends StatefulWidget {
  static const String routeName = '/add-house-sell';

  const AddHouseRentScreen({super.key});

  @override
  State<AddHouseRentScreen> createState() => _AddHouseRentScreenState();
}

class _AddHouseRentScreenState extends State<AddHouseRentScreen> {
  // ======================= СЕТЫ ДЛЯ ДИАЛОГОВ =======================

  Set<String> _selectedHouseTypes = {}; // Тип дома
  Set<String> _selectedWallTypes = {};
  Set<String> _selectedHousingClassTypes = {};
  Set<String> _selectedHeatingTypes = {};
  Set<String> _selectedCommunicationTypes = {};
  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};
  Set<String> _selectedRegion = {};
  Set<String> _selectedRoomCounts = {};
  Set<String> _selectedRenovationTypes = {};
  Set<String> _selectedMultimediaTypes = {};
  Set<String> _selectedComfortTypes = {};
  Set<String> _selectedDistanceToCity = {};
  Set<String> _selectedLandAreaTypes = {};
  Set<String> _selectedOuterInsulationTypes = {};
  Set<String> _selectedRoofTypes = {};
  Set<String> _selectedSaunaTypes = {};

  // ======================= КАРТИНКИ =======================

  final List<File> _images = [];
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

  // ======================= СТЕЙТ ПЕРЕКЛЮЧАТЕЛЕЙ =======================

  bool isIndividualSelected = true; // Частное лицо / Бизнес
  bool isSecondarySelected = true; // Вторичка / Новостройка
  bool isMortgage = false; // Ипотека
  bool isInstallment = false; // Рассрочка

  bool isBargain = false; // Возможен торг
  bool isNoCommission = false; // Без комиссии
  bool isExchange = false; // Возможность обмена
  bool isRealtorReady = false; // Готов сотрудничать с риэлтором
  bool isUrgentBuyout = false; // Срочный выкуп
  bool isDeveloperSale = false; // Продажа от застройщика
  bool isRosreestr = false; // Учёт в рос реестре

  bool isAutoRenewal = false; // Автопродление
  bool? _selectedFurnished = true; // Меблирован: да/нет

  String _selectedAction = 'publish'; // preview / publish

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
              // ---------------- HEADER ----------------
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

              const Text(
                'Опишите товар или услугу',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 17),

              // ---------------- ФОТО ----------------
              GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
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

              // ---------------- ЗАГОЛОВОК ----------------
              _buildTextField(
                label: 'Заголовок объявления',
                hint: 'Например, уютный дом у моря',
              ),
              const SizedBox(height: 7),
              const Text(
                'Введите не менее 16 символов',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 15),

              // ---------------- КАТЕГОРИЯ ----------------
              _buildDropdown(
                label: 'Категория',
                hint: 'Долгосрочная аренда домов',
                subtitle: 'Недвижимость',
                showChangeText: true,
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

              // ---------------- ОПИСАНИЕ ----------------
              _buildTextField(
                label: 'Описание',
                hint:
                    'Чем больше информации вы укажете о вашем объекте, тем привлекательнее он будет для покупателей. Без ссылок, телефонов, матершинных слов.',
                minLength: 70,
                maxLines: 4,
                height: 149,
              ),

              const SizedBox(height: 24),

              // ---------------- ЦЕНА ----------------
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
                          const Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textPrimary),
                              decoration: InputDecoration(
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
                    child: const Text(
                      '₽',
                      style: TextStyle(color: textPrimary, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ---------------- ЧЕКБОКСЫ ПОСЛЕ ЦЕНЫ ----------------
              _buildCheckboxRow(
                title: 'Возможен торг',
                value: isBargain,
                onChanged: (v) => setState(() => isBargain = v),
              ),
              const SizedBox(height: 12),
              _buildCheckboxRow(
                title: 'Без комиссии',
                value: isNoCommission,
                onChanged: (v) => setState(() => isNoCommission = v),
              ),
              const SizedBox(height: 12),
              _buildCheckboxRow(
                title: 'Возможность обмена',
                value: isExchange,
                onChanged: (v) => setState(() => isExchange = v),
              ),
              const SizedBox(height: 12),
              _buildCheckboxRow(
                title: 'Готов сотрудничать с риэлтором',
                value: isRealtorReady,
                onChanged: (v) => setState(() => isRealtorReady = v),
              ),

              const SizedBox(height: 12),
              _buildCheckboxRow(
                title: 'Продажа от застройщика',
                value: isDeveloperSale,
                onChanged: (v) => setState(() => isDeveloperSale = v),
              ),

              const SizedBox(height: 12),
              _buildCheckboxRow(
                title: 'Учёт в рос реестре',
                value: isRosreestr,
                onChanged: (v) => setState(() => isRosreestr = v),
              ),

              const SizedBox(height: 18),

              // ---------------- ВИД ОБЪЕКТА ----------------
              const Text(
                'Вид объекта',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Вторичка',
                    isSecondarySelected,
                    () => setState(() => isSecondarySelected = true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Новостройка',
                    !isSecondarySelected,
                    () => setState(() => isSecondarySelected = false),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ---------------- ХАРАКТЕРИСТИКИ ----------------
              _buildDropdown(
                label: 'Расстояние до ближайшего города',
                hint: _selectedDistanceToCity.isEmpty
                    ? 'Выбрать'
                    : _selectedDistanceToCity.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Расстояние до \nближайшего города',
                        options: const [
                          'В городе',
                          'До 5 км',
                          'До 10 км',
                          'До 15 км',
                          'До 20 км',
                          'До 25 км',
                          'До 30 км',
                          'До 35 км',
                          'До 40 км',
                          'До 45 км',
                          'До 50 км',
                          'До 55 км',
                        ],
                        selectedOptions: _selectedDistanceToCity,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedDistanceToCity = selected);
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Этажность',
                hint: 'Общее количество этажей',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Общая площадь (м²)',
                hint: 'Цифрами',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Количество комнат',
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
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Количество комнат',
                        options: const ['1', '2', '3', '4', '5', '6+'],
                        selectedOptions: _selectedRoomCounts,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedRoomCounts = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Площадь участка (соток)',
                hint: _selectedLandAreaTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedLandAreaTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Площадь участка (соток)',
                        options: const [
                          'До 5',
                          '5–10',
                          '10–15',
                          '15–20',
                          '20–30',
                          'Более 30',
                        ],
                        selectedOptions: _selectedLandAreaTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedLandAreaTypes = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Тип дома',
                hint: _selectedHouseTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedHouseTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
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
                        onSelectionChanged: (selected) {
                          setState(() => _selectedHouseTypes = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Кадастровый номер',
                hint: 'Кадастровый номер',
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
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Класс жилья',
                        options: const [
                          'Эконом',
                          'Комфорт',
                          'Бизнес',
                          'Премиум',
                        ],
                        selectedOptions: _selectedHousingClassTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedHousingClassTypes = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Год постройки / сдачи',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  // По макету тоже dropdown — можно будет подвязать отдельный диалог
                },
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
                    builder: (context) {
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
                        onSelectionChanged: (selected) {
                          setState(() => _selectedWallTypes = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Внешнее утепление стен',
                hint: _selectedOuterInsulationTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedOuterInsulationTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Внешнее утепление стен',
                        options: const [
                          'Без утепления',
                          'Минеральная вата',
                          'Пенопласт',
                          'Пенополистирол',
                          'Пенополиуретан',
                          'Комбинированное',
                          'Другое',
                        ],
                        selectedOptions: _selectedOuterInsulationTypes,
                        onSelectionChanged: (selected) {
                          setState(
                            () => _selectedOuterInsulationTypes = selected,
                          );
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Тип кровли',
                hint: _selectedRoofTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedRoofTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Тип кровли',
                        options: const [
                          'Металлочерепица',
                          'Профнастил',
                          'Шифер',
                          'Гибкая черепица',
                          'Ондулин',
                          'Плоская кровля',
                          'Деревянная',
                          'Комбинированная',
                          'Другое',
                        ],
                        selectedOptions: _selectedRoofTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedRoofTypes = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Санузел',
                hint: _selectedSaunaTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedSaunaTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Санузел',
                        options: const [
                          'Отсутствует',
                          'В доме',
                          'Отдельно стоящая',
                          'Баня',
                          'Хамам',
                        ],
                        selectedOptions: _selectedSaunaTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedSaunaTypes = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
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
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Отопление',
                        options: const [
                          'Централизованное',
                          'Собственная котельная',
                          'Индивидуальное газовое',
                          'Индивидуальное электро',
                          'Твердотопливное',
                          'Тепловой насос',
                          'Комбинированное',
                          'Другое',
                        ],
                        selectedOptions: _selectedHeatingTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedHeatingTypes = selected);
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
                hint: _selectedRenovationTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedRenovationTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Ремонт',
                        options: const [
                          'Авторский проект',
                          'Евроремонт',
                          'Косметический ремонт',
                          'Жилое состояние',
                          'После строителей',
                          'Под чистовую отделку',
                          'Аварийное состояние',
                        ],
                        selectedOptions: _selectedRenovationTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedRenovationTypes = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              const Text(
                'Меблирован',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Да',
                    _selectedFurnished == true,
                    () => setState(() => _selectedFurnished = true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Нет',
                    _selectedFurnished == false,
                    () => setState(() => _selectedFurnished = false),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _buildDropdown(
                label: 'Мультимедиа',
                hint: _selectedMultimediaTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedMultimediaTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Мультимедиа',
                        options: const [
                          'Wi-Fi',
                          'Скоростной интернет',
                          'ПК, принтер, сканер',
                          'Телевизор',
                          'Кабельное, цифровое ТВ',
                          'Спутниковое ТВ',
                          'Домашний кинотеатр',
                          'X-box, Playstation',
                          'Без мультимедиа',
                        ],
                        selectedOptions: _selectedMultimediaTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedMultimediaTypes = selected);
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Комфорт',
                hint: _selectedComfortTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedComfortTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Комфорт',
                        options: const [
                          'Все объявления',
                          'Подогрев полов',
                          'Автоматное отопление',
                          'Односпальная кровать',
                          'Двухспальная кровать',
                          'Доп. спальное место',
                          'Ванна',
                          'Душевая кабина',
                          'Сауна',
                          'Джакузи',
                          'Бильярд',
                          'Кондиционер',
                          'Утюг, гладильная доска',
                          'Гардероб',
                          'Сейф',
                          'Видеонаблюдение',
                          'Охраняемая территория',
                          'Терраса',
                          'Парковочное место',
                          'Фитнес-центр, спортзал',
                          'Бассейн',
                          'Баня',
                          'Сауна',
                          'Хамам',
                        ],
                        selectedOptions: _selectedComfortTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedComfortTypes = selected);
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
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
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Коммуникации',
                        options: const [
                          'Газ',
                          'Центральный водопровод',
                          'Скважина',
                          'Электричество',
                          'Центральная канализация',
                          'Септик',
                          'Вывоз отходов',
                          'Без коммуникаций',
                        ],
                        selectedOptions: _selectedCommunicationTypes,
                        onSelectionChanged: (selected) {
                          setState(
                            () => _selectedCommunicationTypes = selected,
                          );
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Инфраструктура (до 500 метров)',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Инфраструктура (до 500 метров)',
                        options: const [
                          'Центр города',
                          'Достопримечательности',
                          'Исторические места',
                          'Музеи, выставки',
                          'Парк, зеленая зона',
                          'Детская площадка',
                          'Отделения банка, банкомат',
                          'Супермаркет, магазин',
                          'Остановка транспорта',
                          'Стоянка',
                          'Рынок',
                          'Горнолыжные трассы',
                          'Автовокзал',
                          'ЖД станция',
                        ],
                        selectedOptions: _selectedCommunicationTypes,
                        onSelectionChanged: (selected) {
                          setState(
                            () => _selectedCommunicationTypes = selected,
                          );
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Ландшафт (до 1 км)',
                hint: 'Выбрать',
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Ландшафт (до 1 км)',
                        options: const [
                          'Река',
                          'Водохранилище',
                          'Водопад',
                          'Озеро',
                          'Море',
                          'Океан',
                          'Острова',
                          'Холмы',
                          'Горы',
                          'Каньоны',
                          'Парк',
                          'Пещеры',
                          'Лес',
                          'Пляж',
                          'Город',
                        ],
                        selectedOptions: _selectedCommunicationTypes,
                        onSelectionChanged: (selected) {
                          setState(
                            () => _selectedCommunicationTypes = selected,
                          );
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 21),

              // ---------------- ЧАСТНОЕ ЛИЦО / БИЗНЕС ----------------
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

              // ---------------- АВТОПРОДЛЕНИЕ ----------------
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Автопродление',
                          style: TextStyle(color: textPrimary, fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Объявление будет деактивировано\nчерез 30 дней',
                          style: TextStyle(color: textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  CustomSwitch(
                    value: isAutoRenewal,
                    onChanged: (v) => setState(() => isAutoRenewal = v),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---------------- АДРЕС ----------------
              _buildDropdown(
                label: 'Ваша область*',
                hint: _selectedRegion.isEmpty
                    ? 'Ваша область'
                    : _selectedRegion.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Ваша область',
                        options: const [
                          'Алтайский край',
                          'Краснодарский край',
                          'Московская область',
                          'Ленинградская область',
                          'Ростовская область',
                          'Новосибирская область',
                        ],
                        selectedOptions: _selectedRegion,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedRegion = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

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
                    builder: (context) {
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
                        onSelectionChanged: (selected) {
                          setState(() => _selectedCity = selected);
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
                    builder: (context) {
                      return StreetSelectionDialog(
                        title: 'Улица',
                        groupedOptions: const {
                          'Центральный район': [
                            'Аэродромная улица',
                            'Бахмутская улица',
                            'бул. Богдана Хмельницкого',
                            'бул. Шевченко Георгиевская',
                            'ул. Гранитная',
                            'ул. Греческая',
                            'ул. Евпаторийская',
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
                        onSelectionChanged: (selected) {
                          setState(() => _selectedStreet = selected);
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
                'Месторасположение*',
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

              // ---------------- КОНТАКТНЫЕ ДАННЫЕ ----------------
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
                hint: 'https://',
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Ссылка на ваш whatsapp',
                hint: 'https://',
              ),

              const SizedBox(height: 22),

              // ---------------- КНОПКИ ----------------
              _buildButton(
                'Предпросмотр',
                onPressed: () {
                  setState(() => _selectedAction = 'preview');
                  // Здесь позже можно открыть экран предпросмотра
                },
                isPrimary: _selectedAction == 'preview',
              ),
              const SizedBox(height: 10),
              _buildButton(
                'Опубликовать',
                onPressed: () {
                  setState(() => _selectedAction = 'publish');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PublicationTariffScreen(),
                    ),
                  );
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

  // ============================================================
  // ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
  // ============================================================

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
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text(
                      'Изменить',
                      style: TextStyle(color: Colors.blue, fontSize: 14),
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

  Widget _buildCheckboxRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              title,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
        ),
        CustomCheckbox(value: value, onChanged: (v) => onChanged(v)),
      ],
    );
  }
}
