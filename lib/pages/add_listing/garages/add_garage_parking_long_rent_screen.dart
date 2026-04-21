import 'dart:io';

import 'package:flutter/material.dart';

import '../real_estate_subcategories_screen.dart';
import '../publication_tariff_screen.dart';

import 'package:lidle/widgets/components/custom_switch.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/street_selection_dialog.dart';
import 'package:lidle/widgets/form_fields/photo_picker_field.dart';
import 'package:lidle/widgets/form_fields/price_field.dart';

import '../../../constants.dart';

/// ============================================================
/// Экран: Создание объявления — Долгосрочная аренда гаражей
/// ============================================================
class AddGarageParkingLongRentScreen extends StatefulWidget {
  static const String routeName = '/add-garage-rent';

  const AddGarageParkingLongRentScreen({super.key});

  @override
  State<AddGarageParkingLongRentScreen> createState() =>
      _AddGarageParkingLongRentScreenState();
}

class _AddGarageParkingLongRentScreenState
    extends State<AddGarageParkingLongRentScreen> {
  // ======================= СЕТЫ ДЛЯ ДИАЛОГОВ =======================

  Set<String> _selectedLandType = {};
  Set<String> _selectedLocationTypes = {};
  Set<String> _selectedCommunicationTypes = {};
  Set<String> _selectedInfrastructureTypes = {};
  Set<String> _selectedComfortTypes = {};
  Set<String> _selectedRegion = {};
  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};

  // ======================= КАРТИНКИ =======================

  List<File> _images = [];

  void _onImagesChanged(List<File> images) {
    setState(() => _images = images);
  }

  // ======================= СТЕЙТ ПЕРЕКЛЮЧАТЕЛЕЙ =======================

  String _price = '';

  bool isIndividualSelected = true;

  bool isBargain = false;
  bool isNoCommission = false;
  bool isHourlyRent = false;
  bool isExchange = false;
  bool isFlightWithChildren = false;
  bool isWithChildren = false;
  bool isHourlyAvailable = false;
  bool isPetsAllowed = false;
  bool isCooperationWithRealtor = false;
  bool isUrgentBuyout = false;
  bool isRosreestr = false;
  bool isForSharedRental = false;
  bool isAutoRenewal = false;

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
              // ================= HEADER =================
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

              // ================= Фото =================
              PhotoPickerField(
                initialImages: _images,
                onImagesChanged: _onImagesChanged,
              ),
              const SizedBox(height: 13),

              // ============ Заголовок объявления ============
              _buildTextField(
                label: 'Заголовок объявления',
                hint: 'Например, участок под ИЖС',
              ),
              const SizedBox(height: 7),
              const Text(
                'Введите не менее 16 символов',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 15),

              // ============ Категория ===============
              _buildDropdown(
                label: 'Категория',
                hint: 'Долгосрочная аренда гаражей, парковок',
                subtitle: 'Недвижимость / Гаражи, парковки ',
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

              // ============ Описание ============
              _buildTextField(
                label: 'Описание',
                hint:
                    'Чем больше информации вы укажете о вашем товаре, тем более привлекательее он будет для клиентов.Без ссылок, телефонов, матерных слов.',
                minLength: 70,
                maxLines: 4,
                height: 149,
              ),

              const SizedBox(height: 12),

              // ============ Цена ============
              const Text(
                'Цена*',
                style: TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 9),

              PriceField(
                initialPrice: _price,
                initialIsBargain: isBargain,
                initialIsNoCommission: isNoCommission,
                onPriceChanged: (value) => setState(() => _price = value),
                onIsBargainChanged: (value) => setState(() => isBargain = value),
                onIsNoCommissionChanged: (value) => setState(() => isNoCommission = value),
              ),

              const SizedBox(height: 15),

              // ============ Чекбоксы ============
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
                title: 'Готов сотрудничать с риэлтором',
                value: isCooperationWithRealtor,
                onChanged: (v) => setState(() => isCooperationWithRealtor = v),
              ),
             
              const SizedBox(height: 12),
              _buildCheckboxRow(
                title: 'Для совместной аренды',
                value: isForSharedRental,
                onChanged: (v) => setState(() => isForSharedRental = v),
              ),

              const SizedBox(height: 18),

              // =======================================================
              // ХАРАКТЕРИСТИКИ ЗЕМЕЛЬНОГО УЧАСТКА
              // =======================================================
              _buildDropdown(
                label: 'Тип недвижимости',
                hint: _selectedLandType.isEmpty
                    ? 'Выбрать'
                    : _selectedLandType.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Тип недвижимости',
                        options: const [
                          'Бизнес-центр',
                          'Торгово-офисный центр',
                          'Административное здание',
                          'Нежилое помещение в \nжилом фонде',
                          'Житловий фонд',
                          'Другое',
                        ],
                        selectedOptions: _selectedLandType,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedLandType = selected);
                        },
                        allowMultipleSelection: false,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),
              _buildDropdown(
                label: 'Расположение',
                hint: _selectedLocationTypes.isEmpty
                    ? 'Выбрать'
                    : _selectedLocationTypes.join(', '),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textSecondary,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SelectionDialog(
                        title: 'Расположение',
                        options: const [
                          'Цокольный этаж / подвал',
                          'Фасадное помещение',
                          'Отдельное помещение',
                          'Отдельное здание',
                          'Часть здания',
                          'Другое',
                        ],
                        selectedOptions: _selectedLocationTypes,
                        onSelectionChanged: (selected) {
                          setState(() => _selectedLocationTypes = selected);
                        },
                        allowMultipleSelection: true,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 9),

              _buildTextField(
                label: 'Общая площадь (м²)',
                hint: 'Цифрами',
                keyboardType: TextInputType.number,
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
                          'Центор города',
                          'Достопримечательности',
                          'Исторические места',
                          'Музеи выставки',
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

              const SizedBox(height: 16),

              // ================= Частное лицо / Бизнес =================
              const Text(
                'Частное лицо / Бизнес*',
                style: TextStyle(color: textPrimary, fontSize: 16),
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

              // ================= Автопродление =================
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

              // ================= Адрес =================
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
                            'ул. Гранитная',
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

              // ================= Контактные данные =================
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

              // ================= Кнопки =================
              _buildButton(
                'Предпросмотр',
                onPressed: () => setState(() => _selectedAction = 'preview'),
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
  // ================ ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ===================
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: subtitle != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hint,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          hint,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
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
