import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../real_estate_subcategories_screen.dart';
import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/street_selection_dialog.dart';
import '../publication_tariff_screen.dart';

import '../../../constants.dart';

// ============================================================
// "Виджет: Экран добавления квартиры в недвижимость"
// ============================================================
class AddApartmentAbroadSellScreen extends StatefulWidget {
  static const String routeName = '/add-real-estate-apt';

  const AddApartmentAbroadSellScreen({super.key});

  @override
  State<AddApartmentAbroadSellScreen> createState() =>
      _AddApartmentAbroadSellScreenState();
}

// ============================================================
// "Класс состояния: Управление состоянием экрана добавления квартиры"
// ============================================================
class _AddApartmentAbroadSellScreenState
    extends State<AddApartmentAbroadSellScreen> {
  // ============================================================
  // "Переменные состояния: Хранение выбранных опций для формы квартиры"
  // ============================================================
  Set<String> _selectedHouseTypes = {};
  Set<String> _selectedDealTypes = {};
  Set<String> _selectedWallTypes = {};
  Set<String> _selectedHousingClassTypes = {};
  Set<String> _selectedHeatingTypes = {};
  Set<String> _selectedCommunicationTypes = {};
  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};
  Set<String> _selectedRoomCounts = {};
  Set<String> _selectedLayoutTypes = {};
  Set<String> _selectedBathroomTypes = {};
  Set<String> _selectedRenovationTypes = {};
  Set<String> _selectedAppliancesTypes = {};
  Set<String> _selectedMultimediaTypes = {};
  Set<String> _selectedComfortTypes = {};
  Set<String> _selectedInfrastructureTypes = {};
  Set<String> _selectedLandscapeTypes = {};
  Set<String> _selectedRegion = {};
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  final TextEditingController floorController = TextEditingController();
  final TextEditingController floorsController = TextEditingController();

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
  bool isObjectTypeYes = true;
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
  bool? _selectedFurnished = true;

  String _selectedAction = 'publish';

  void _togglePersonType(bool isIndividual) {
    setState(() => isIndividualSelected = isIndividual);
  }

  void _toggleMortgage(bool yes) {
    setState(() => isMortgageYes = yes);
  }

  void _toggleObjectType(bool yes) {
    setState(() => isObjectTypeYes = yes);
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
              ),
              const SizedBox(height: 7),
              Text(
                'Введите не менее 16 символов',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 15),

              _buildDropdown(
                label: 'Категория',
                hint: 'Продажа квартир за рубежом ',
                subtitle: 'Недвижимость / За рубежом',
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

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isBargain = !isBargain),
                      child: const Text(
                        'Возможен торг',
                        style: TextStyle(color: textPrimary, fontSize: 14),
                      ),
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => isNoCommission = !isNoCommission),
                      child: const Text(
                        'Без комиссии',
                        style: TextStyle(color: textPrimary, fontSize: 14),
                      ),
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isExchange = !isExchange),
                      child: const Text(
                        'Возможность обмена',
                        style: TextStyle(color: textPrimary, fontSize: 14),
                      ),
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isPledge = !isPledge),
                      child: const Text(
                        'Готов сотрудничать с риэлтором',
                        style: TextStyle(color: textPrimary, fontSize: 14),
                      ),
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isUrgent = !isUrgent),
                      child: const Text(
                        'Срочная продажа',
                        style: TextStyle(color: textPrimary, fontSize: 14),
                      ),
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => isInstallment = !isInstallment),
                      child: const Text(
                        'Продажа от застройщика',
                        style: TextStyle(color: textPrimary, fontSize: 14),
                      ),
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isRemoteDeal = !isRemoteDeal),
                      child: const Text(
                        'Учёт в рос реестре',
                        style: TextStyle(color: textPrimary, fontSize: 14),
                      ),
                    ),
                  ),
                  CustomCheckbox(
                    value: isRemoteDeal,
                    onChanged: (v) => setState(() => isRemoteDeal = v),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              const Text(
                'Вид обьекта*',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton(
                    'Вторичка',
                    isObjectTypeYes,
                    () => _toggleObjectType(true),
                  ),
                  const SizedBox(width: 10),
                  _buildChoiceButton(
                    'Новострой',
                    !isObjectTypeYes,
                    () => _toggleObjectType(false),
                  ),
                ],
              ),

              const SizedBox(height: 13),

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

              _buildTextField(label: 'Общая площадь(м²)*', hint: 'Цифрами'),
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
                        options: const ['1', '2', '3', '4', '5', '6+'],
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
                hint: _selectedLayoutTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedLayoutTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Планировка',
                        options: const [
                          'Смежная, проходная',
                          'Раздельная',
                          'Студия',
                          'Пентхаус',
                          'Многоуровневая',
                          'Малосемека, гостинка',
                        ],
                        selectedOptions: _selectedLayoutTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedLayoutTypes = selected;
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
                label: 'Санузел',
                hint: _selectedBathroomTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedBathroomTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Санузел',
                        options: const [
                          'Раздельный',
                          'Смежный',
                          '2 и более',
                          'Санузел отсутствует',
                        ],
                        selectedOptions: _selectedBathroomTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedBathroomTypes = selected;
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
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Ремонт',
                        options: const [
                          'Авторский проект',
                          'Евроремонт',
                          'Косметический ремонт',
                          'Жилое состояние',
                          'После строительства',
                          'Под чистовую отделку',
                          'Аварийное состояние',
                        ],
                        selectedOptions: _selectedRenovationTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedRenovationTypes = selected;
                          });
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              const Text(
                'Мебелирован',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChoiceButton('Да', _selectedFurnished == true, () {
                    setState(() {
                      _selectedFurnished = true;
                    });
                  }),
                  const SizedBox(width: 10),
                  _buildChoiceButton('Нет', _selectedFurnished == false, () {
                    setState(() {
                      _selectedFurnished = false;
                    });
                  }),
                ],
              ),
              const SizedBox(height: 18),

              _buildDropdown(
                label: 'Бытовая техника',
                hint: _selectedAppliancesTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedAppliancesTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Бытовая техника',
                        options: const [
                          'Электрочайник',
                          'Кофемашина',
                          'Фен',
                          'Плита',
                          'Варочная панель',
                          'Микроволновая печь',
                          'Мультиварка',
                          'Холодильник',
                          'Посудомоечная машина',
                          'Стиральная машина',
                          'Сушильная машина',
                          'Утюг',
                          'Пылесос',
                          'Без бытовой техники',
                        ],
                        selectedOptions: _selectedAppliancesTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedAppliancesTypes = selected;
                          });
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

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
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Мультимедиа',
                        options: const [
                          'Wi-Fi',
                          'Скоростной интернет',
                          'ПК, принтер, сканер',
                          'Телевизор',
                          'Кабильное, цифровое ТВ',
                          'Спутниковое ТВ',
                          'Домашний кинотеатр',
                          'X-box, Playstation',
                          'Без мультимедиа',
                        ],
                        selectedOptions: _selectedMultimediaTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedMultimediaTypes = selected;
                          });
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
                    builder: (BuildContext context) {
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
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedComfortTypes = selected;
                          });
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
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 9),

              _buildRange(
                "Площадь кухни(м²)",
                floorController,
                floorsController,
              ),

              const SizedBox(height: 9),

              _buildTextField(
                label: 'Год постройки',
                hint: 'Укажите год',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 9),

              _buildDropdown(
                label: 'Инфраструктура (до 500 метров)',
                hint: _selectedInfrastructureTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedInfrastructureTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Инфраструктура (до 500 метров)',
                        options: const [
                          'Центр города',
                          'Достопримечательности',
                          'Исторические места',
                          'Музеи выставки',
                          'Парк, зеленая зона',
                          'Детская площадка',
                          'Отделения банка, банкомат',
                          'Аптека',
                          'Супермаркет, магазин',
                          'Остановка транспорта',
                          'Стоянка',
                          'Рынок',
                          'Горнолыжные трассы',
                          'Автовокзал',
                          'ЖД станция',
                        ],
                        selectedOptions: _selectedInfrastructureTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedInfrastructureTypes = selected;
                          });
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
                hint: _selectedLandscapeTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedLandscapeTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return SelectionDialog(
                        title: 'Ландшафт (до 1 км)',
                        options: const [
                          'Река',
                          'Водохранилище',
                          'Водопад',
                          'Озера',
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
                        selectedOptions: _selectedLandscapeTypes,
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedLandscapeTypes = selected;
                          });
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 27),

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
                hint: 'https:',
              ),
              const SizedBox(height: 9),

              _buildTextField(label: 'Ссылка на ваш whatsapp', hint: 'https:'),

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
                  setState(() {
                    _selectedAction = 'publish';
                  });
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

  Widget _buildRange(
    String label,
    TextEditingController fromController,
    TextEditingController toController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: formBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: fromController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'От',
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: formBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: toController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'До',
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
          ],
        ),
      ],
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
}
