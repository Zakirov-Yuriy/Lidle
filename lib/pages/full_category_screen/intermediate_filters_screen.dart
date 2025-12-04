import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/full_category_screen/real_estate_full_subcategories_screen.dart';
import 'package:lidle/widgets/city_selection_dialog.dart';
// основной экран фильтров

class IntermediateFiltersScreen extends StatefulWidget {
  static const String routeName = "/intermediate-filters";

  const IntermediateFiltersScreen({super.key});

  @override
  State<IntermediateFiltersScreen> createState() =>
      _IntermediateFiltersScreenState();
}

class _IntermediateFiltersScreenState extends State<IntermediateFiltersScreen> {
  // сортировка
  String selectedSort = "recommended";

  // валюта
  String selectedCurrency = "uah";

  // тип продавца
  String sellerType = "business";

  // view mode
  String viewMode = "gallery";

  // город
  Set<String> selectedCities = {};

  // список городов
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

  // Цена
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
                    _buildSectionTitle("Сортировка"),
                    const SizedBox(height: 18),

                    _buildSortButtons(),

                    const SizedBox(height: 18),
                    _buildSectionTitle("Выберите категорию"),
                    _buildClickableBox(value: "Недвижимость", onTap: () {}),

                    const SizedBox(height: 18),
                    _buildSectionTitle("Выберите город"),
                    _buildClickableBox(
                      value: selectedCities.isEmpty ? "Выбрать" : selectedCities.first,
                      icon: Icons.chevron_right,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => CitySelectionDialog(
                            title: "Выберите город",
                            options: cities,
                            selectedOptions: selectedCities,
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                selectedCities = newSelection;
                              });
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),
                    _buildSectionTitle("Валюта"),
                    const SizedBox(height: 18),
                    _buildCurrencyButtons(),

                    const SizedBox(height: 18),
                    _buildSectionTitle("Цена"),
                    const SizedBox(height: 18),
                    _buildPriceFields(),

                    const SizedBox(height: 18),
                    _buildSectionTitle("Частное лицо / Бизнес"),
                    const SizedBox(height: 18),
                    _buildSellerTypeButtons(),

                    // const SizedBox(height: 25),
                    // _buildViewModeSelector(),

                    // const SizedBox(height: 20),
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

  // ---------------- HEADER -------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),

              const SizedBox(width: 16),

              const Spacer(),

              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSort = "recommended";
                    selectedCurrency = "uah";
                    selectedCities.clear();
                    priceFrom.clear();
                    priceTo.clear();
                    sellerType = "business";
                    viewMode = "gallery";
                  });
                },
                child: const Text(
                  "ОЧИСТИТЬ ВСЕ",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          Row(
            children: const [
              SizedBox(height: 12),
              Text(
                "Фильтры",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- SECTION TITLE -------------------

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

  // ---------------- SORT BUTTONS -------------------

  Widget _buildSortButtons() {
    return Row(
      children: [
        _buildSelectableButton(
          text: "Рекомендованное вам",
          isActive: selectedSort == "recommended",
          onTap: () => setState(() => selectedSort = "recommended"),
        ),
        const SizedBox(width: 10),
        _buildSelectableButton(
          text: "Самые новые",
          isActive: selectedSort == "newest",
          onTap: () => setState(() => selectedSort = "newest"),
        ),
      ],
    );
  }

  // ---------------- SELECTABLE BUTTON -------------------

  Widget _buildSelectableButton({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeIconColor : primaryBackground,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isActive ? activeIconColor : Colors.white,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color:  Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- CLICKABLE BOX -------------------

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

  // ---------------- CURRENCY BUTTONS -------------------

  Widget _buildCurrencyButtons() {
    return Row(
      children: [
        _buildSelectableButton(
          text: "₽",
          isActive: selectedCurrency == "uah",
          onTap: () => setState(() => selectedCurrency = "uah"),
        ),
        const SizedBox(width: 10),
        _buildSelectableButton(
          text: "\$",
          isActive: selectedCurrency == "usd",
          onTap: () => setState(() => selectedCurrency = "usd"),
        ),
        const SizedBox(width: 10),
        _buildSelectableButton(
          text: "€",
          isActive: selectedCurrency == "eur",
          onTap: () => setState(() => selectedCurrency = "eur"),
        ),
      ],
    );
  }

  // ---------------- PRICE FIELDS -------------------

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

  // ---------------- SELLER TYPE -------------------

  Widget _buildSellerTypeButtons() {
    return Row(
      children: [
        _buildSelectableButton(
          text: "Бизнес",
          isActive: sellerType == "business",
          onTap: () => setState(() => sellerType = "business"),
        ),
        const SizedBox(width: 10),
        _buildSelectableButton(
          text: "Частное",
          isActive: sellerType == "private",
          onTap: () => setState(() => sellerType = "private"),
        ),
      ],
    );
  }

  // ---------------- VIEW MODE -------------------

  // Widget _buildViewModeSelector() {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(vertical: 12),
  //     decoration: const BoxDecoration(color: Color(0xFF151B24)),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceAround,
  //       children: [
  //         _buildViewModeItem(Icons.grid_view, "ГАЛЕРЕЯ", "gallery"),
  //         _buildViewModeItem(Icons.list_alt, "СПИСОК", "list"),
  //         _buildViewModeItem(Icons.table_rows, "ПЛИТКА", "tiles"),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildViewModeItem(IconData icon, String label, String key) {
  //   bool active = viewMode == key;

  //   return GestureDetector(
  //     onTap: () => setState(() => viewMode = key),
  //     child: Column(
  //       children: [
  //         Icon(icon, color: active ? const Color(0xFF1AD1C5) : Colors.white60),
  //         const SizedBox(height: 4),
  //         Text(
  //           label,
  //           style: TextStyle(
  //             color: active ? const Color(0xFF1AD1C5) : Colors.white60,
  //             fontSize: 11,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ---------------- APPLY BUTTON -------------------

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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RealEstateFullSubcategoriesScreen(),
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
}
