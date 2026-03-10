import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/full_category_screen/real_estate_full_subcategories_screen.dart';
import 'package:lidle/pages/full_category_screen/real_estate_full_filters_screen.dart';
import 'package:lidle/widgets/dialogs/city_selection_dialog.dart';
import 'package:lidle/widgets/selectable_button.dart';

// ============================================================
// "Промежуточный экран фильтров"
// ============================================================

class IntermediateFiltersScreen extends StatefulWidget {
  static const String routeName = "/intermediate-filters";

  final String? displayTitle; // Динамически подтягиваемый заголовок из real_estate_listings_screen

  const IntermediateFiltersScreen({
    super.key,
    this.displayTitle,
  });

  @override
  State<IntermediateFiltersScreen> createState() =>
      _IntermediateFiltersScreenState();
}

class _IntermediateFiltersScreenState extends State<IntermediateFiltersScreen> {
  String selectedDateSort = ""; // Новые или Старые
  String selectedPriceSort = ""; // Дорогие или Дешевые

  String selectedCurrency = "uah";

  String sellerType = "";

  String viewMode = "gallery";

  // Выбранная категория и тип апартамента
  String? selectedSubcategory;
  String? selectedApartmentType;

  Set<String> selectedCities = {};
  Set<String> selectedStreet = {};
  Set<String> selectedCity = {};

  final List<String> cities = [
    'Киев',
    'Харьков',
    'Одесса',
    'Днепр',
    'Запорожье',
    'Львов',
    'Кривой Рог',
    'Николаев',
    'Мариуполь',
    'Винница',
    'Херсон',
    'Полтава',
    'Черкассы',
    'Черновцы',
    'Житомир',
    'Сумы',
    'Хмельницкий',
    'Ровно',
    'Ивано-Франковск',
    'Тернополь',
    'Луцк',
    'Ужгород',
  ];

  final TextEditingController priceFrom = TextEditingController();
  final TextEditingController priceTo = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryFilterBlock(),

                    // const SizedBox(height: 18),
                    // _buildSectionTitle("Выберите категорию"),
                    // _buildClickableBox(
                    //   value: "Недвижимость",
                    //   icon: Icons.close,
                    //   onTap: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) =>
                    //             const RealEstateFullSubcategoriesScreen(),
                    //       ),
                    //     );
                    //   },
                    // ),

                    // const SizedBox(height: 18),
                    // _buildSectionTitle("Выберите город"),
                    // _buildClickableBox(
                    //   value: selectedCities.isEmpty
                    //       ? "Выбрать"
                    //       : selectedCities.first,
                    //   icon: Icons.chevron_right,
                    //   onTap: () {
                    //     showDialog(
                    //       context: context,
                    //       builder: (context) => CitySelectionDialog(
                    //         title: "Выберите город",
                    //         options: cities,
                    //         selectedOptions: selectedCities,
                    //         onSelectionChanged: (Set<String> newSelection) {
                    //           setState(() {
                    //             selectedCities = newSelection;
                    //           });
                    //         },
                    //       ),
                    //     );
                    //   },
                    // ),

                    // const SizedBox(height: 18),
                    // _buildSectionTitle("Валюта"),
                    // const SizedBox(height: 18),
                    // _buildCurrencyButtons(),

                    // const SizedBox(height: 18),
                    // _buildSectionTitle("Цена"),
                    // const SizedBox(height: 18),
                    // _buildPriceFields(),

                    const SizedBox(height: 18),
                    _buildSortBlock(),

                    const SizedBox(height: 18),
                    _buildSectionTitle("Частное лицо / Бизнес"),
                    const SizedBox(height: 18),
                    _buildSellerTypeButtons(),
                  ],
                ),
              ),
            ),

            _buildApplyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 5),
              Text(
                "Фильтры",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(width: 16),

              const Spacer(),

              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDateSort = "";
                    selectedPriceSort = "";
                    selectedCurrency = "uah";
                    selectedCities.clear();
                    priceFrom.clear();
                    priceTo.clear();
                    sellerType = "";
                    viewMode = "gallery";
                  });
                },
                child: const Text(
                  "Сбросить",
                  style: TextStyle(color: activeIconColor, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildClickableBox({
    required String value,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C232D),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            if (icon != null) Icon(icon, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyButtons() {
    return Row(
      children: [
        SelectableButton(
          text: "₽",
          isActive: selectedCurrency == "uah",
          onTap: () => setState(() => selectedCurrency = "uah"),
          maxWidth: 175,
        ),
        // const SizedBox(width: 10),
        // SelectableButton(
        //   text: "\$",
        //   isActive: selectedCurrency == "usd",
        //   onTap: () => setState(() => selectedCurrency = "usd"),
        //   maxWidth: 200,
        // ),
        // const SizedBox(width: 10),
        // SelectableButton(
        //   text: "€",
        //   isActive: selectedCurrency == "eur",
        //   onTap: () => setState(() => selectedCurrency = "eur"),
        //   maxWidth: 200,
        // ),
      ],
    );
  }

  Widget _buildPriceFields() {
    return Row(
      children: [
        Expanded(child: _buildPriceInput("От", priceFrom)),
        const SizedBox(width: 10),
        Expanded(child: _buildPriceInput("До", priceTo)),
      ],
    );
  }

  Widget _buildPriceInput(String hint, TextEditingController controller) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C232D),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
          ),
        ),
      ),
    );
  }

  Widget _buildSellerTypeButtons() {
    return Column(
      children: [
        Row(
          children: [
            
            Expanded(
              child: SelectableButton(
                text: "Все",
                isActive: sellerType == "all",
                onTap: () => setState(() => sellerType = "all"),
                maxWidth: double.infinity,
              ),
            ),

            const SizedBox(width: 10),
            Expanded(
              child: SelectableButton(
                text: "Частное лицо",
                isActive: sellerType == "private",
                onTap: () => setState(() => sellerType = "private"),
                maxWidth: 200,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableButton(
                text: "Бизнес",
                isActive: sellerType == "business",
                onTap: () => setState(() => sellerType = "business"),
                maxWidth: 200,
              ),
            ),
            
            
          ],
          
        ),
       
      ],
    );
  }

  Widget _buildApplyButton() {
    return Container(
      color: primaryBackground,
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBackground,
            minimumSize: const Size.fromHeight(51),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: activeIconColor),
            ),
          ),
          onPressed: () {
            // Переход на экран фильтра с подтянутыми данными из промежуточного фильтра
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RealEstateFullFiltersScreen(
                  selectedCategory: selectedSubcategory ?? widget.displayTitle ?? 'Недвижимость',
                ),
              ),
            );
          },
          child: const Text(
            "Применить",
            style: TextStyle(
              color: activeIconColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// ════════════════════════════════════════════════════════════
  /// Методы-помощники для блока категорий (как в real_estate_full_filters_screen.dart)
  /// ════════════════════════════════════════════════════════════

  Widget _buildCategoryFilterBlock() {
    // Форматируем заголовок: убираем переносы строк и очищаем текст
    final displayCategoryTitle =
        widget.displayTitle?.replaceAll('\n', ' ').trim() ?? 'Недвижимость';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Категории",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildSelectedBox(
          displayCategoryTitle,
          showRemove: false,
          backgroundColor: const Color(0xFF6B7280),
          textColor: Colors.black,
          fitWidth: true,
          verticalPadding: 6,
        ),
        const SizedBox(height: 21),
        _buildTitle("Выберите город"),
        _buildSelector(
          selectedCity.isEmpty ? "Выберите город" : selectedCity.first,
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
                  onSelectionChanged: (v) => setState(() => selectedCity = v),
                );
              },
            );
          },
          showArrow: true,
        ),
        const SizedBox(height: 16),
        _buildTitle("Выберите подкатегорию"),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const RealEstateFullSubcategoriesScreen(),
              ),
            );
            if (result != null) {
              setState(() {
                selectedSubcategory = result;
              });
            }
          },
          child: Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedSubcategory ??
                            widget.displayTitle?.replaceAll('\n', ' ').trim() ??
                            'Недвижимость',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getCategorySubtitle(),
                        style: const TextStyle(
                          color: Color(0xFF7A7A7A),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Выбрать',
                  style: TextStyle(color: Colors.lightBlue, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getCategorySubtitle() {
    final categoryTitle = widget.displayTitle?.replaceAll('\n', ' ').trim() ?? 'Недвижимость';
    final subcategoryTitle = selectedSubcategory ?? categoryTitle;
    return '$categoryTitle / $subcategoryTitle';
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

  Widget _buildSelectedBox(
    String text, {
    required bool showRemove,
    VoidCallback? onRemove,
    Color? backgroundColor,
    Color? textColor,
    bool fitWidth = false,
    double verticalPadding = 12,
  }) {
    return Container(
      width: fitWidth ? null : double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? secondaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: fitWidth ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(text, style: TextStyle(color: textColor ?? Colors.white)),
          if (showRemove)
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, color: Colors.white70),
            ),
        ],
      ),
    );
  }

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
            _sortButton("Новые", "new", "date"),
            const SizedBox(width: 10),
            _sortButton("Старые", "old", "date"),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _sortButton("Дорогие", "expensive", "price"),
            const SizedBox(width: 10),
            _sortButton("Дешевые", "cheap", "price"),
          ],
        ),
      ],
    );
  }

  Widget _sortButton(String label, String value, String sortType) {
    final isActive = sortType == "date"
        ? selectedDateSort == value
        : selectedPriceSort == value;

    return Expanded(
      child: SelectableButton(
        text: label,
        isActive: isActive,
        onTap: () {
          setState(() {
            if (sortType == "date") {
              selectedDateSort = selectedDateSort == value ? "" : value;
            } else {
              selectedPriceSort = selectedPriceSort == value ? "" : value;
            }
          });
        },
        maxWidth: double.infinity,
      ),
    );
  }
}
