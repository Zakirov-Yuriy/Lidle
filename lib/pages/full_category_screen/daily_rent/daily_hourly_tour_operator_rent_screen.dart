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

class DailyHourlyTourOperatorRentScreen extends StatefulWidget {
  static const String routeName = '/real-estate-filters';

  const DailyHourlyTourOperatorRentScreen({super.key});

  @override
  State<DailyHourlyTourOperatorRentScreen> createState() =>
      _DailyHourlyTourOperatorRentScreenState();
}

class _DailyHourlyTourOperatorRentScreenState
    extends State<DailyHourlyTourOperatorRentScreen> {
  String _sortType = 'newest';

  bool isSecondarySelected = true;
  bool isIndividualSelected = true;

  bool isBargain = false;
  bool isNoCommission = false;
  bool isRealtor = false;
  bool isCoRent = false;
  bool isPetsAllowed = false;
  bool isHourlyAvailable = false;
  bool _selectedNutrition = false;
  bool isHourlyRent = false;
  bool isWithChildren = false;

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
  Set<String> _selectedDealTypes = {};
  Set<String> _selectedDistanceToCity = {};
  Set<String> _selectedAdditionalTypes = {};
  Set<String> _selectedCountries = {};

  void _resetFilters() {
    setState(() {
      _sortType = 'newest';
      isSecondarySelected = true;
      isIndividualSelected = true;

      isBargain = false;
      isNoCommission = false;
      isRealtor = false;
      isCoRent = false;
      isPetsAllowed = false;
      isHourlyAvailable = false;
      _selectedNutrition = false;
      isHourlyRent = false;
      isWithChildren = false;

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
      _selectedDealTypes.clear();
      _selectedDistanceToCity.clear();
      _selectedAdditionalTypes.clear();
      _selectedCountries.clear();
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
                    const SizedBox(height: 21),

                    const Divider(height: 1, color: textMuted),
                    const SizedBox(height: 13),

                    _buildCityStreetBlock(),
                    const SizedBox(height: 21),
                    const Divider(height: 1, color: textMuted),
                    const SizedBox(height: 12),

                    _buildCurrencyAndPrice(),
                    const SizedBox(height: 16),

                    _buildPriceCheckboxes(),
                    const SizedBox(height: 20),

                    _buildDropdown(
                      label: 'Стоимость включает',
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
                              title: 'Стоимость включает',
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
                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Тип отеля, базы отдыха',
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
                              title: 'Тип отеля, базы отдыха',
                              options: const [
                                'Эконом',
                                'Комфорт',
                                'Бизнес',
                                'Элит',
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

                    const SizedBox(height: 10),

                    _buildDropdown(
                      label: 'Вариант размешения',
                      hint: _selectedSleepingPlaces.isEmpty
                          ? 'Выбрать'
                          : _selectedSleepingPlaces.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SelectionDialog(
                              title: 'Вариант размешения',
                              options: const [
                                'Все',
                                'Эконом',
                                'Стандарт',
                                'Люкс',
                                'Бизнес-люкс',
                                'Дубплекс',
                                'Представительский люкс',
                                'Президентский люкс',
                              ],
                              selectedOptions: _selectedSleepingPlaces,
                              onSelectionChanged: (Set<String> selected) {
                                setState(() {
                                  _selectedSleepingPlaces = selected;
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
                      label: 'Категория отеля*',
                      hint: _selectedSleepingPlaces.isEmpty
                          ? 'Выбрать'
                          : _selectedSleepingPlaces.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SelectionDialog(
                              title: 'Категория отеля*',
                              options: const [
                                'Эконом',
                                'Комфорт',
                                'Бизнес',
                                'Элит',
                              ],
                              selectedOptions: _selectedSleepingPlaces,
                              onSelectionChanged: (Set<String> selected) {
                                setState(() {
                                  _selectedSleepingPlaces = selected;
                                });
                              },
                              allowMultipleSelection: false,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      'Питание',
                      style: TextStyle(color: textPrimary, fontSize: 16),
                    ),
                    // const SizedBox(height: 1),
                    Row(
                      children: [
                        _buildChoiceButton(
                          'Да',
                          _selectedNutrition,
                          () => setState(() => _selectedNutrition = true),
                        ),
                        const SizedBox(width: 10),
                        _buildChoiceButton(
                          'Нет',
                          !_selectedNutrition,
                          () => setState(() => _selectedNutrition = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
                      label: 'Дополнительно',
                      hint: _selectedAdditionalTypes.isEmpty
                          ? 'Выбрать'
                          : _selectedAdditionalTypes.join(', '),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: textSecondary,
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return SelectionDialog(
                              title: 'Дополнительно',
                              options: const [
                                'Возможность бронирования',
                                'Бронь без аванса',
                                'Можно с детьми',
                                'Можно с питомцами',
                                'Можно купить',
                                'Можно для вечеринок',
                              ],
                              selectedOptions: _selectedAdditionalTypes,
                              onSelectionChanged: (Set<String> selected) {
                                setState(() {
                                  _selectedAdditionalTypes = selected;
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
                  'Предложения Туроператоров',
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
          title: 'Домашние жиивотные',
          value: isPetsAllowed,
          onChanged: (v) => setState(() => isPetsAllowed = v),
        ),
        const SizedBox(height: 8),

        _buildCheckboxRow(
          title: 'С детьми',
          value: isWithChildren,
          onChanged: (v) => setState(() => isWithChildren = v),
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

  Widget _buildChoiceButton(String text, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? activeIconColor : Colors.transparent,
          side: isSelected ? null : const BorderSide(color: Colors.white),
          minimumSize: const Size.fromHeight(35),
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
}
