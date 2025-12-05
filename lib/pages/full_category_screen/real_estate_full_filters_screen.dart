import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/selection_dialog.dart';
import 'package:lidle/widgets/city_selection_dialog.dart';
import 'package:lidle/widgets/street_selection_dialog.dart';
import 'package:lidle/widgets/custom_checkbox.dart';
import 'package:lidle/pages/full_category_screen/real_estate_filtered_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_subfilters_screen.dart';

class RealEstateFullFiltersScreen extends StatefulWidget {
  final String selectedCategory;

  const RealEstateFullFiltersScreen({
    super.key,
    required this.selectedCategory,
  });

  @override
  State<RealEstateFullFiltersScreen> createState() =>
      _RealEstateFullFiltersScreenState();
}

class _RealEstateFullFiltersScreenState
    extends State<RealEstateFullFiltersScreen> {
  // ======================= Остальные поля =======================

  // сделка
  String dealType = "sell"; // sell / rent / joint

  // ипотека
  bool? mortgageYes = true;

  // рассрочка
  bool? installmentYes = true;

  // чекбоксы
  bool noCommission = false;
  bool exchange = false;
  bool urgent = false;
  bool realtor = false;
  bool buyerOffer = false;
  bool registrySale = false;

  // объект
  bool isSecondary = true;

  // частное/бизнес
  bool isPrivate = true;

  // селекты
  Set<String> selectedCity = {};
  Set<String> selectedStreet = {};
  Set<String> selectedBuildingTypes = {};
  Set<String> selectedWallTypes = {};
  Set<String> selectedLayout = {};
  Set<String> selectedBathrooms = {};
  Set<String> selectedHeating = {};
  Set<String> selectedRenovation = {};
  Set<String> selectedComfort = {};
  Set<String> selectedMultimedia = {};
  Set<String> selectedCommunication = {};
  Set<String> selectedInfrastructure = {};
  Set<String> selectedLandscape = {};
  Set<String> selectedRooms = {};

  // текстовые контроллеры
  final houseNumberController = TextEditingController();
  final areaController = TextEditingController();
  final kitchenAreaController = TextEditingController();
  final floorsController = TextEditingController();
  final floorController = TextEditingController();
  final constructionMin = TextEditingController();
  final constructionMax = TextEditingController();

  // ======================= UI =======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 19),
              _buildSortBlock(),
              const SizedBox(height: 27),
              const Divider(color: Colors.white24),
              const SizedBox(height: 22),
              // ============ КАТЕГОРИЯ ============
              _buildTitle("Выберите категорию"),
              _buildSelectedBox(
                widget.selectedCategory,
                showRemove: true,
                onRemove: () => Navigator.pop(context),
              ),
              const SizedBox(height: 21),
              const Divider(color: Colors.white24),
              const SizedBox(height: 13),

              // ============ ГОРОД ============
              _buildTitle("Выберите город"),
              _buildSelector(
                selectedCity.isEmpty ? "Мариуполь" : selectedCity.first,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return CitySelectionDialog(
                        title: "Выберите город",
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
                        selectedOptions: selectedCity,
                        onSelectionChanged: (v) =>
                            setState(() => selectedCity = v),
                      );
                    },
                  );
                },
                showArrow: true,
              ),
              const SizedBox(height: 16),

              // ============ УЛИЦА ============
              _buildTitle("Выберите улицу"),
              _buildSelector(
                selectedStreet.isEmpty ? "Центр" : selectedStreet.join(", "),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return StreetSelectionDialog(
                        title: "Улица",
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
                        selectedOptions: selectedStreet,
                        onSelectionChanged: (v) =>
                            setState(() => selectedStreet = v),
                      );
                    },
                  );
                },
                showArrow: true,
              ),

              // Номер дома
              const SizedBox(height: 16),
              _buildTitle("Номер дома"),
              _buildInput("12", houseNumberController),
              const SizedBox(height: 21),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),

              _buildTitle("Вид сделки"),
              const SizedBox(height: 4),
              _buildThreeButtons(
                labels: const ["Совместная", "Продажа", "Аренда"],
                selectedIndex: dealType == "joint"
                    ? 0
                    : dealType == "sell"
                    ? 1
                    : 2,
                onSelect: (i) {
                  setState(() {
                    dealType = i == 0
                        ? "joint"
                        : i == 1
                        ? "sell"
                        : "rent";
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RealEstateSubfiltersScreen(
                        selectedCategory: widget.selectedCategory,
                        selectedDealType: dealType,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white24),
              const SizedBox(height: 27),

              _buildTitle("Валюта: Российский рубль (₽)"),
              _buildTitle("Цена"),

              // Цена
              _buildPriceBlock(),

              const SizedBox(height: 15),

              // ============ ЧЕКБОКСЫ ============
              _buildCheck("Без комиссии", noCommission, (v) {
                setState(() => noCommission = v);
              }),
              const SizedBox(height: 13),
              _buildCheck("Возможность обмена", exchange, (v) {
                setState(() => exchange = v);
              }),
              const SizedBox(height: 13),
              _buildCheck("Готов сотрудничать с риэлтором", noCommission, (v) {
                setState(() => noCommission = v);
              }),
              const SizedBox(height: 13),
              _buildCheck("Срочная продажа", urgent, (v) {
                setState(() => urgent = v);
              }),
              const SizedBox(height: 13),
              _buildCheck("Пpодажа от застройщика", registrySale, (v) {
                setState(() => registrySale = v);
              }),
              const SizedBox(height: 13),
              _buildCheck("Учёт в росреестре", realtor, (v) {
                setState(() => realtor = v);
              }),
              const SizedBox(height: 13),
              _buildCheck("Пpедложить свою цену", buyerOffer, (v) {
                setState(() => buyerOffer = v);
              }),

              const SizedBox(height: 16),

              // ============ ИПОТЕКА ============
              _buildTitle("Ипотека"),
              const SizedBox(height: 4),
              _buildToggleYesNo(
                labelYes: "Да",
                labelNo: "Нет",
                selected: mortgageYes,
                onChange: (v) => setState(() => mortgageYes = v),
              ),

              const SizedBox(height: 12),

              // ============ РАССРОЧКА ============
              _buildTitle("Рассрочка"),
              const SizedBox(height: 4),
              _buildToggleYesNo(
                labelYes: "Да",
                labelNo: "Нет",
                selected: installmentYes,
                onChange: (v) => setState(() => installmentYes = v),
              ),

              const SizedBox(height: 17),

              // ============ СЕЛЕКТЫ ============
              _buildSelectorDropdown(
                label: "Тип дома",
                selected: selectedBuildingTypes,
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
                onChanged: (v) => setState(() => selectedBuildingTypes = v),
              ),

              const SizedBox(height: 10),
              _buildTitle("Название ЖК"),

              _buildInput("Название ЖК", areaController),

              const SizedBox(height: 10),
              _buildRange("Этаж", floorController, floorsController),

              const SizedBox(height: 10),
              _buildRange("Этажность", floorController, floorsController),

              const SizedBox(height: 10),
              _buildSelectorDropdown(
                label: "Тип сделки",
                selected: selectedRooms,
                options: const [
                  'От застройщика',
                  'Переуступка',
                  'Рассрочка от',
                  'Рассрочка от банка',
                  'Банковский кредит',
                  'Лизинг',
                ],
                onChanged: (v) => setState(() => selectedRooms = v),
              ),

              const SizedBox(height: 10),

              _buildRange(
                "Общая площадь (м²)",
                floorController,
                floorsController,
              ),

              const SizedBox(height: 10),
              _buildSelectorDropdown(
                label: "Тип стен",
                selected: selectedWallTypes,
                options: const [
                  'Кирпичный',
                  'Панельный',
                  'Монолитный',
                  'Шлакоблочный',
                  'Деревянный',
                  'Газоблок',
                  'СИП панель',
                  'Другое',
                ],
                onChanged: (v) => setState(() => selectedWallTypes = v),
              ),

              const SizedBox(height: 15),
              _buildSelectorDropdown(
                label: "Класс жилья",
                selected: selectedComfort,
                options: const [
                  'Эконом',
                  'Комфорт',
                  'Бизнес',
                  'Элит',
                  'Другое',
                ],
                onChanged: (v) => setState(() => selectedComfort = v),
              ),

              const SizedBox(height: 15),
              _buildSelectorDropdown(
                label: "Количество комнат",
                selected: selectedRooms,
                options: const [
                  '1 комната',
                  '2 комнаты',
                  '3 комнаты',
                  '4 комнаты',
                  '5 комнат',
                  'Другое',
                ],
                onChanged: (v) => setState(() => selectedRooms = v),
              ),

              const SizedBox(height: 15),
              _buildSelectorDropdown(
                label: "Планировка",
                selected: selectedLayout,
                options: const [
                  'Смежная, проходная',
                  'Раздельная',
                  'Студия',
                  'Пентхаус',
                  'Многоуровневая',
                  'Малосемека, гостинка',
                ],
                onChanged: (v) => setState(() => selectedLayout = v),
              ),

              const SizedBox(height: 15),
              _buildSelectorDropdown(
                label: "Санузел",
                selected: selectedBathrooms,
                options: const [
                  'Раздельный',
                  'Смежный',
                  '2 и более',
                  'Санузел отсутствует',
                ],
                onChanged: (v) => setState(() => selectedBathrooms = v),
              ),

              const SizedBox(height: 15),
              _buildSelectorDropdown(
                label: "Отопление",
                selected: selectedHeating,
                options: const [
                  'Все объявления',
                  'Централизованное',
                  'Собственная котельная',
                  'Индивидуальное газовое',
                  'Индивидуальное электро',
                  'Твердотопленное',
                  'Тепловой насос',
                  'Комбинированное',
                  'Другое',
                ],
                onChanged: (v) => setState(() => selectedHeating = v),
              ),

              const SizedBox(height: 15),
              _buildSelectorDropdown(
                label: "Ремонт",
                selected: selectedRenovation,
                options: const [
                  'Аторский проект',
                  'Евроремонт',
                  'Косметический ремонт',
                  'Жилое состояние',
                  'После строителей',
                  'Под чистовую отделку',
                  'Аварийное состояние',
                ],
                onChanged: (v) => setState(() => selectedRenovation = v),
              ),

              const SizedBox(height: 13),
              _buildTitle("Меблирована"),
              // const SizedBox(height: 4),
              _buildToggleYesNo(
                labelYes: "С мебелью",
                labelNo: "Без мебели",
                selected: mortgageYes,
                onChange: (v) {},
              ),

              const SizedBox(height: 12),
              _buildSelectorDropdown(
                label: "Бытовая техника",
                selected: selectedMultimedia,
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
                onChanged: (v) => setState(() => selectedMultimedia = v),
              ),

              const SizedBox(height: 12),
              _buildSelectorDropdown(
                label: "Мультимедиа",
                selected: selectedMultimedia,
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
                onChanged: (v) => setState(() => selectedMultimedia = v),
              ),

              const SizedBox(height: 12),
              _buildSelectorDropdown(
                label: "Комфорт",
                selected: selectedComfort,
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
                onChanged: (v) => setState(() => selectedComfort = v),
              ),

              const SizedBox(height: 12),
              _buildSelectorDropdown(
                label: "Коммуникации",
                selected: selectedCommunication,
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
                onChanged: (v) => setState(() => selectedCommunication = v),
              ),

              const SizedBox(height: 12),
              _buildSelectorDropdown(
                label: "Инфраструктура (до 500 метров)",
                selected: selectedInfrastructure,
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
                onChanged: (v) => setState(() => selectedInfrastructure = v),
              ),

              const SizedBox(height: 12),
              _buildRange(
                "Площадь кухни (м²)",
                kitchenAreaController,
                areaController,
              ),

              const SizedBox(height: 12),
              _buildTitle("Вид обьекта"),
              const SizedBox(height: 4),
              _buildToggleYesNo(
                labelYes: "Вторичка",
                labelNo: "Новостройка",
                selected: mortgageYes,
                onChange: (v) {},
              ),
              const SizedBox(height: 12),
              _buildRange("Год постройки", constructionMin, constructionMax),

              const SizedBox(height: 12),
              _buildSelectorDropdown(
                label: "Ландшафт (до 1 км)",
                selected: selectedLandscape,
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
                onChanged: (v) => setState(() => selectedLandscape = v),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 14),

              _buildTitle("Частное лицо / Бизнес"),
              const SizedBox(height: 4),
              _buildTwoOption(
                yes: "Частное лицо",
                no: "Бизнес",
                selected: isPrivate,
                onChange: (v) => setState(() => isPrivate = v),
              ),

              const SizedBox(height: 21),
              const Divider(color: Colors.white24),
              const SizedBox(height: 21),

              // нижние кнопки
              _buildBottomButtons(),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  // ========== HEADER ==========
  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 13),
        const Text(
          "Фильтры",
          style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 255, 255, 255)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: const Text(
            "Сбросить",
            style: TextStyle(color: Colors.lightBlue, fontSize: 16),
          ),
        ),
      ],
    );
  }

  // --- сортировка ---
  String? selectedDateSort = "new"; // "new" or "old"
  String? selectedPriceSort; // "expensive" or "cheap"

  Widget _buildSortBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Сортировка",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            _sortButton("Новые", "new"),
            const SizedBox(width: 10),
            _sortButton("Старые", "old"),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _sortButton("Дорогие", "expensive"),
            const SizedBox(width: 10),
            _sortButton("Дешевые", "cheap"),
          ],
        ),
      ],
    );
  }

  Widget _sortButton(String label, String key) {
    final bool isActive = (key == "new" || key == "old")
        ? selectedDateSort == key
        : selectedPriceSort == key;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (key == "new" || key == "old") {
              selectedDateSort = key;
            } else if (key == "expensive" || key == "cheap") {
              selectedPriceSort = key;
            }
          });
        },
        child: Container(
          height: 35,
          decoration: BoxDecoration(
            color: isActive ? activeIconColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? Colors.transparent : Colors.white70,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== TITLE ==========
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

  // ========== SELECTED BOX (категория) ==========
  Widget _buildSelectedBox(
    String text, {
    required bool showRemove,
    VoidCallback? onRemove,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // margin: const EdgeInsets.only(top: 9),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
          if (showRemove)
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  // ========== SELECTOR BOX ==========
  Widget _buildSelector(
    String text, {
    VoidCallback? onTap,
    bool showArrow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white)),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // ========== PRICE ==========
  Widget _buildPriceBlock() {
    return Row(
      children: [
        Expanded(child: _buildInput("От", areaController)),
        const SizedBox(width: 12),
        Expanded(child: _buildInput("До", areaController)),
      ],
    );
  }

  // ========== CHECKBOX ==========
  Widget _buildCheck(String text, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
        ),

        CustomCheckbox(value: value, onChanged: onChanged),
      ],
    );
  }

  // ========== TOGGLE YES/NO ==========
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
          color: active ? Colors.lightBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? Colors.transparent : Colors.white70,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: active ? Colors.white : Colors.white70),
          ),
        ),
      ),
    );
  }

  // ========== THREE BUTTONS ==========
  Widget _buildThreeButtons({
    required List<String> labels,
    required int selectedIndex,
    required Function(int) onSelect,
  }) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                height: 35,
                margin: EdgeInsets.only(right: i != labels.length - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: selectedIndex == i
                      ? Colors.lightBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selectedIndex == i
                        ? Colors.transparent
                        : Colors.white70,
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selectedIndex == i ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ========== DROPDOWN ==========
  Widget _buildSelectorDropdown({
    required String label,
    required Set<String> selected,
    required List<String> options,
    required Function(Set<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(label),
        // const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) {
                return SelectionDialog(
                  title: label,
                  options: options,
                  selectedOptions: selected,
                  onSelectionChanged: onChanged,
                  allowMultipleSelection: true,
                );
              },
            );
          },
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected.isEmpty ? "Выбрать" : selected.join(", "),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========== RANGE ==========
  Widget _buildRange(
    String label,
    TextEditingController a,
    TextEditingController b,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(label),
        // const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildInput("От", a)),
            const SizedBox(width: 12),
            Expanded(child: _buildInput("До", b)),
          ],
        ),
      ],
    );
  }

  // ========== TEXT INPUT ==========
  Widget _buildInput(String label, TextEditingController controller) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: label,
            hintStyle: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ========== TWO OPTION ==========
  Widget _buildTwoOption({
    required String yes,
    required String no,
    required bool selected,
    required Function(bool) onChange,
  }) {
    return Row(
      children: [
        Expanded(child: _toggleButton(yes, selected, () => onChange(true))),
        const SizedBox(width: 10),
        Expanded(child: _toggleButton(no, !selected, () => onChange(false))),
      ],
    );
  }

  // ========== BOTTOM BUTTONS ==========
  Widget _buildBottomButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size.fromHeight(51),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            
            onPressed: () {},
            child: const Text(
              "Сохранить настройки фильтра",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white70),
              minimumSize: const Size.fromHeight(51),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {},
            child: const Text(
              "Показать на карте",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              minimumSize: const Size.fromHeight(51),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RealEstateFilteredScreen(selectedCategory: widget.selectedCategory)),
              );
            },
            child: const Text(
              "Показать",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
