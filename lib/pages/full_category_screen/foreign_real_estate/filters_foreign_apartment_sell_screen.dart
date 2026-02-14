import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/dialogs/street_selection_dialog.dart';

// ============================================================
// "Экран фильтров для аренды недвижимости"
// ============================================================

class FiltersForeignApartmentSellScreen extends StatefulWidget {
  static const String routeName = '/real-estate-filters';

  const FiltersForeignApartmentSellScreen({super.key});

  @override
  State<FiltersForeignApartmentSellScreen> createState() =>
      _FiltersForeignApartmentSellScreenState();
}

class _FiltersForeignApartmentSellScreenState
    extends State<FiltersForeignApartmentSellScreen> {
  String _sortType = 'newest';

  bool isSecondarySelected = true;
  bool isIndividualSelected = true;
  bool? _isFurnished;

  bool isBargain = false;
  bool isNoCommission = false;
  bool isRealtor = false;
  bool isCoRent = false;
  bool isPetsAllowed = false;
  bool isExchange = false;
  bool urgent = false;
  bool isDeveloperSale = false;
  bool isRosreestr = false;
  bool isMortgageYes = true;
  bool? installmentYes = false;

  Set<String> _selectedHouseTypes = {};
  Set<String> _selectedWallTypes = {};
  Set<String> _selectedHousingClassTypes = {};
  Set<String> _selectedRoomCounts = {};
  Set<String> _selectedSleepingPlaces = {};
  Set<String> _selectedLayoutTypes = {};
  Set<String> _selectedBathroomTypes = {};
  Set<String> _selectedHeatingTypes = {};
  Set<String> _selectedRenovationTypes = {};
  Set<String> _selectedAppliancesTypes = {};
  Set<String> _selectedMultimediaTypes = {};
  Set<String> _selectedComfortTypes = {};
  Set<String> _selectedCommunicationTypes = {};
  Set<String> _selectedInfrastructureTypes = {};
  Set<String> _selectedLandscapeTypes = {};
  Set<String> _selectedCity = {};
  Set<String> _selectedStreet = {};
  Set<String> _selectedCountries = {};
  Set<String> _selectedDealTypes = {};

  void _resetFilters() {
    setState(() {
      _sortType = 'newest';
      isSecondarySelected = true;
      isIndividualSelected = true;
      _isFurnished = null;

      isBargain = false;
      isNoCommission = false;
      isRealtor = false;
      isCoRent = false;
      isPetsAllowed = false;
      isExchange = false;
      urgent = false;
      isDeveloperSale = false;
      isRosreestr = false;
      isMortgageYes = true;
      installmentYes = false;

      _selectedHouseTypes.clear();
      _selectedWallTypes.clear();
      _selectedHousingClassTypes.clear();
      _selectedRoomCounts.clear();
      _selectedSleepingPlaces.clear();
      _selectedLayoutTypes.clear();
      _selectedBathroomTypes.clear();
      _selectedHeatingTypes.clear();
      _selectedRenovationTypes.clear();
      _selectedAppliancesTypes.clear();
      _selectedMultimediaTypes.clear();
      _selectedComfortTypes.clear();
      _selectedCommunicationTypes.clear();
      _selectedInfrastructureTypes.clear();
      _selectedLandscapeTypes.clear();
      _selectedCity.clear();
      _selectedStreet.clear();
      _selectedCountries.clear();
      _selectedDealTypes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 25, top: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const Header()],
              ),
            ),
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSortSection(),
                    const SizedBox(height: 22),
                    const Divider(height: 1, color: textMuted),
                    const SizedBox(height: 22),

                    _buildCategorySelector(),
                    const SizedBox(height: 16),

                    _buildDropdown(
                      label: 'Страна',
                      hint: _selectedCountries.isEmpty
                          ? 'Выбрать'
                          : _selectedCountries.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SelectionDialog(
                              title: 'Страна',
                              options: const [
                                'Россия',
                                'Украина',
                                'Беларусь',
                                'Казахстан',
                                'Узбекистан',
                                'Киргизия',
                                'Таджикистан',
                                'Туркмения',
                                'Армения',
                                'Азербайджан',
                                'Грузия',
                                'Молдова',
                                'Латвия',
                                'Литва',
                                'Эстония',
                              ],
                              selectedOptions: _selectedCountries,
                              onSelectionChanged: (Set<String> selected) {
                                setState(() {
                                  _selectedCountries = selected;
                                });
                              },
                              allowMultipleSelection: true,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 9),

                    _buildCityStreetBlock(),
                    const SizedBox(height: 21),
                    const Divider(height: 1, color: textMuted),
                    const SizedBox(height: 12),

                    _buildCurrencyAndPrice(),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Вид объекта'),
                    const SizedBox(height: 10),
                    _buildTwoChoiceRow(
                      left: 'Вторичка',
                      right: 'Новостройка',
                      isLeftSelected: isSecondarySelected,
                      onLeftTap: () =>
                          setState(() => isSecondarySelected = true),
                      onRightTap: () =>
                          setState(() => isSecondarySelected = false),
                    ),
                    const SizedBox(height: 30),

                    _buildPriceCheckboxes(),
                    const SizedBox(height: 20),

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

                    const SizedBox(height: 10),

                    _buildTitle("Рассрочка"),
                    const SizedBox(height: 4),
                    _buildToggleYesNo(
                      labelYes: "Да",
                      labelNo: "Нет",
                      selected: installmentYes,
                      onChange: (v) => setState(() => installmentYes = v),
                    ),
                    const SizedBox(height: 19),

                    _buildDropdown(
                      label: 'Тип дома',
                      hint: _selectedHouseTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedHouseTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
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
                          selected: _selectedHouseTypes,
                          allowMultiple: false,
                          onChanged: (s) =>
                              setState(() => _selectedHouseTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      label: 'Название ЖК',
                      hint: 'Название жилого комплекса',
                    ),
                    const SizedBox(height: 10),

                    _buildRangeFields(
                      label: 'Этаж',
                      leftHint: 'От',
                      rightHint: 'До',
                    ),
                    const SizedBox(height: 10),

                    _buildRangeFields(
                      label: 'Этажность',
                      leftHint: 'От',
                      rightHint: 'До',
                    ),
                    const SizedBox(height: 10),

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
                    const SizedBox(height: 10),

                    _buildRangeFields(
                      label: 'Общая площадь (м²)',
                      leftHint: 'От',
                      rightHint: 'До',
                    ),
                    const SizedBox(height: 10),

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
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Класс жилья',
                      hint: _selectedHousingClassTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedHousingClassTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
                          title: 'Класс жилья',
                          options: const [
                            'Эконом',
                            'Комфорт',
                            'Бизнес',
                            'Премиум',
                          ],
                          selected: _selectedHousingClassTypes,
                          allowMultiple: false,
                          onChanged: (s) =>
                              setState(() => _selectedHousingClassTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Количество комнат',
                      hint: _selectedRoomCounts.isEmpty
                          ? 'Выбрать'
                          : _selectedRoomCounts.join(', '),
                      onTap: () {
                        _openSelectionDialog(
                          title: 'Количество комнат',
                          options: const [
                            'Студия',
                            '1',
                            '2',
                            '3',
                            '4',
                            '5',
                            '6+',
                          ],
                          selected: _selectedRoomCounts,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedRoomCounts = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Планировка',
                      hint: _selectedLayoutTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedLayoutTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
                          title: 'Планировка',
                          options: const [
                            'Смежная, проходная',
                            'Раздельная',
                            'Студия',
                            'Пентхаус',
                            'Многоуровневая',
                            'Малосемейка, гостинка',
                          ],
                          selected: _selectedLayoutTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedLayoutTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Санузел',
                      hint: _selectedBathroomTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedBathroomTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
                          title: 'Санузел',
                          options: const [
                            'Раздельный',
                            'Смежный',
                            '2 и более',
                            'Санузел отсутствует',
                          ],
                          selected: _selectedBathroomTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedBathroomTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Отопление',
                      hint: _selectedHeatingTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedHeatingTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
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
                          selected: _selectedHeatingTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedHeatingTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Ремонт',
                      hint: _selectedRenovationTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedRenovationTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
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
                          selected: _selectedRenovationTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedRenovationTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Меблированная'),
                    const SizedBox(height: 10),
                    _buildTwoChoiceRow(
                      left: 'С мебелью',
                      right: 'Без мебели',
                      isLeftSelected: _isFurnished == true,
                      onLeftTap: () => setState(() => _isFurnished = true),
                      onRightTap: () => setState(() => _isFurnished = false),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdown(
                      label: 'Бытовая техника',
                      hint: _selectedAppliancesTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedAppliancesTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
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
                          selected: _selectedAppliancesTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedAppliancesTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Мультимедиа',
                      hint: _selectedMultimediaTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedMultimediaTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
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
                          selected: _selectedMultimediaTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedMultimediaTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Коммуникации',
                      hint: _selectedCommunicationTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedCommunicationTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
                          title: 'Коммуникации',
                          options: const [
                            'Газ',
                            'Центральное водоснабжение',
                            'Скважина',
                            'Электричество',
                            'Центральная канализация',
                            'Септик',
                            'Вывоз отходов',
                            'Без коммуникаций',
                          ],
                          selected: _selectedCommunicationTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedCommunicationTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildRangeFields(
                      label: 'Площадь кухни (м²)',
                      leftHint: 'От',
                      rightHint: 'До',
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Инфраструктура (до 500 метров)',
                      hint: _selectedInfrastructureTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedInfrastructureTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
                          title: 'Инфраструктура (до 500 метров)',
                          options: const [
                            'Центр города',
                            'Достопримечательности',
                            'Исторические места',
                            'Музеи, выставки',
                            'Парк, зелёная зона',
                            'Детская площадка',
                            'Отделения банка, банкомат',
                            'Супермаркет, магазин',
                            'Остановка транспорта',
                            'Стоянка',
                            'Рынок',
                            'Автовокзал',
                            'ЖД станция',
                          ],
                          selected: _selectedInfrastructureTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedInfrastructureTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Ландшафт (до 1 км)',
                      hint: _selectedLandscapeTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedLandscapeTypes.join(', '),
                      onTap: () {
                        _openSelectionDialog(
                          title: 'Ландшафт (до 1 км)',
                          options: const [
                            'Река',
                            'Водохранилище',
                            'Озеро',
                            'Море',
                            'Холмы',
                            'Горы',
                            'Парк',
                            'Лес',
                            'Пляж',
                            'Городской пейзаж',
                          ],
                          selected: _selectedLandscapeTypes,
                          allowMultiple: true,
                          onChanged: (s) =>
                              setState(() => _selectedLandscapeTypes = s),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildRangeFields(
                      label: 'Год постройки',
                      leftHint: 'От',
                      rightHint: 'До',
                    ),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Частное лицо / Бизнес'),
                    const SizedBox(height: 10),
                    _buildTwoChoiceRow(
                      left: 'Частное лицо',
                      right: 'Бизнес',
                      isLeftSelected: isIndividualSelected,
                      onLeftTap: () =>
                          setState(() => isIndividualSelected = true),
                      onRightTap: () =>
                          setState(() => isIndividualSelected = false),
                    ),
                    const SizedBox(height: 24),

                    _buildBottomButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: textPrimary),
          ),
          const SizedBox(width: 10),
          const Text(
            'Фильтры',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _resetFilters,
            child: const Text(
              'Сбросить',
              style: TextStyle(color: activeIconColor, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Сортировка'),
        const SizedBox(height: 1),
        Row(
          children: [
            _buildSortButton(
              text: 'Самые новые',
              isSelected: _sortType == 'newest',
              onTap: () => setState(() => _sortType = 'newest'),
            ),
            const SizedBox(width: 10),
            _buildSortButton(
              text: 'Самые дешёвые',
              isSelected: _sortType == 'cheapest',
              onTap: () => setState(() => _sortType = 'cheapest'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 185.0),
          child: Row(
            children: [
              _buildSortButton(
                text: 'Самые дорогие',
                isSelected: _sortType == 'expensive',
                onTap: () => setState(() => _sortType = 'expensive'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? activeIconColor : Colors.transparent,
          side: isSelected
              ? null
              : const BorderSide(color: Colors.white, width: 1),
          minimumSize: const Size(0, 35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : textPrimary,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Выберите категорию'),
        const SizedBox(height: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: const [
              Expanded(
                child: Text(
                  'Продажа квартир за рубежом',
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.close, color: textSecondary, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCityStreetBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdown(
          label: 'Выберите город',
          hint: _selectedCity.isEmpty ? 'Город' : _selectedCity.join(', '),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) {
                return CitySelectionDialog(
                  title: 'Ваш город',
                  options: const [
                    'Маруполь',
                    'Москва',
                    'Санкт-Петербург',
                    'Новосибирск',
                    'Екатеринбург',
                    'Казань',
                  ],
                  selectedOptions: _selectedCity,
                  onSelectionChanged: (s) {
                    setState(() => _selectedCity = s);
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        _buildDropdown(
          label: 'Выберите улицу',
          hint: _selectedStreet.isEmpty ? 'Улица' : _selectedStreet.join(', '),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) {
                return StreetSelectionDialog(
                  title: 'Улица',
                  groupedOptions: const {
                    'Центральный район': ['Центр', 'Советская', 'Ленина'],
                    'Другие районы': ['Мира', 'Гагарина'],
                  },
                  selectedOptions: _selectedStreet,
                  onSelectionChanged: (s) {
                    setState(() => _selectedStreet = s);
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        _buildTextField(label: 'Номер дома', hint: '12'),
      ],
    );
  }

  Widget _buildCurrencyAndPrice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Валюта: Российский рубль (₽)'),
        const SizedBox(height: 12),
        _buildRangeFields(
          label: 'Цена',
          leftHint: 'От',
          rightHint: 'До',
          showSuffix: true,
          suffix: '₽',
        ),
      ],
    );
  }

  Widget _buildPriceCheckboxes() {
    return Column(
      children: [
        _buildCheckboxRow(
          title: 'Возможен торг',
          value: isBargain,
          onChanged: (v) => setState(() => isBargain = v),
        ),
        const SizedBox(height: 8),
        _buildCheckboxRow(
          title: 'Без комиссии',
          value: isNoCommission,
          onChanged: (v) => setState(() => isNoCommission = v),
        ),

        const SizedBox(height: 8),

        _buildCheckboxRow(
          title: 'Возможность обмена',
          value: isExchange,
          onChanged: (v) => setState(() => isExchange = v),
        ),

        const SizedBox(height: 8),
        _buildCheckboxRow(
          title: 'Готов сотрудничать с риэлтором',
          value: isRealtor,
          onChanged: (v) => setState(() => isRealtor = v),
        ),

        const SizedBox(height: 8),
        _buildCheck("Срочная продажа", urgent, (v) {
          setState(() => urgent = v);
        }),
        const SizedBox(height: 8),

        _buildCheckboxRow(
          title: 'Продажа от застройщика',
          value: isDeveloperSale,
          onChanged: (v) => setState(() => isDeveloperSale = v),
        ),

        const SizedBox(height: 8),

        _buildCheckboxRow(
          title: 'Учёт в рос реестре',
          value: isRosreestr,
          onChanged: (v) => setState(() => isRosreestr = v),
        ),
      ],
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

  Widget _buildCheck(String text, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              text,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
        ),
        CustomCheckbox(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () {},
            child: Text(
              'Сохранить настройки фильтра',
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () {},
            child: const Text(
              'Показать на карте',
              style: TextStyle(color: textPrimary, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeIconColor,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Показать',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        const SizedBox(height: 8),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: TextField(
              keyboardType: keyboardType,
              style: const TextStyle(color: textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
                  fontSize: 14,
                ),
              ).copyWith(hintText: hint),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeFields({
    required String label,
    required String leftHint,
    required String rightHint,
    bool showSuffix = false,
    String suffix = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: leftHint,
                      hintStyle: const TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: rightHint,
                            hintStyle: const TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (showSuffix)
                        Text(
                          suffix,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required VoidCallback onTap,
    Widget? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hint,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 14,
                    ),
                  ),
                ),
                icon ??
                    const Icon(Icons.keyboard_arrow_down, color: textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoChoiceRow({
    required String left,
    required String right,
    required bool isLeftSelected,
    required VoidCallback onLeftTap,
    required VoidCallback onRightTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: isLeftSelected
                  ? activeIconColor
                  : Colors.transparent,
              side: isLeftSelected
                  ? null
                  : const BorderSide(color: Colors.white),
              minimumSize: const Size.fromHeight(35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            onPressed: onLeftTap,
            child: Text(
              left,
              style: TextStyle(
                color: isLeftSelected ? Colors.white : textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: !isLeftSelected
                  ? activeIconColor
                  : Colors.transparent,
              side: !isLeftSelected
                  ? null
                  : const BorderSide(color: Colors.white),
              minimumSize: const Size.fromHeight(35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            onPressed: onRightTap,
            child: Text(
              right,
              style: TextStyle(
                color: !isLeftSelected ? Colors.white : textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openSelectionDialog({
    required String title,
    required List<String> options,
    required Set<String> selected,
    required bool allowMultiple,
    required ValueChanged<Set<String>> onChanged,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return SelectionDialog(
          title: title,
          options: options,
          selectedOptions: selected,
          allowMultipleSelection: allowMultiple,
          onSelectionChanged: onChanged,
        );
      },
    );
  }

  void _toggleMortgage(bool value) {
    setState(() => isMortgageYes = value);
  }

  Widget _buildChoiceButton(String text, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? activeIconColor : Colors.transparent,
          side: isSelected ? null : const BorderSide(color: Colors.white),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: onTap,
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

  Widget _buildToggleYesNo({
    required String labelYes,
    required String labelNo,
    required bool? selected,
    required Function(bool?) onChange,
  }) {
    return Row(
      children: [
        Expanded(
          child: _toggleButton(labelYes, selected == true, () {
            onChange(true);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _toggleButton(labelNo, selected == false, () {
            onChange(false);
          }),
        ),
      ],
    );
  }

  Widget _toggleButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 35,
        decoration: BoxDecoration(
          color: active ? activeIconColor : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? Colors.transparent : Colors.white),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: active ? Colors.white : Colors.white),
          ),
        ),
      ),
    );
  }
}
