import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';

// ============================================================
// "Полный экран подкатегорий в выбранной категории недвижимости"
// ============================================================

class RealEstateFullApartmentsScreen extends StatefulWidget {
  final String selectedCategory;
  final List<dynamic>? categoryChildren;

  const RealEstateFullApartmentsScreen({
    super.key,
    this.selectedCategory = 'Недвижимость',
    this.categoryChildren,
  });

  @override
  State<RealEstateFullApartmentsScreen> createState() =>
      _RealEstateFullApartmentsScreenState();
}

class _RealEstateFullApartmentsScreenState
    extends State<RealEstateFullApartmentsScreen> {

  @override
  Widget build(BuildContext context) {
    // Используем переданные подкатегории или статичный список по умолчанию
    final apartments = widget.categoryChildren?.isNotEmpty == true
        ? widget.categoryChildren!.map((child) => child.name as String).toList()
        : [
            'Продажа ${widget.selectedCategory.toLowerCase()}',
            'Долгосрочная аренда ${widget.selectedCategory.toLowerCase()}',
            'Посуточная аренда ${widget.selectedCategory.toLowerCase()}',
          ];

    return Scaffold(
      backgroundColor: primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 23, top: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [const Header()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.arrow_back_ios,
                            color: activeIconColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Назад',
                            style: TextStyle(
                              color: activeIconColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Отмена',
                        style: TextStyle(color: activeIconColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25, bottom: 55),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Недвижимость: ${widget.selectedCategory}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...apartments.map((apartment) => _buildOptionTile(context, apartment)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String title) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          onTap: () {
            // Возвращаемся на intermediate_filters_screen с выбранным видом апартаментов
            Navigator.pop(context, title);
          },
        ),
        const Divider(color: Colors.white24, height: 0.9),
      ],
    );
  }
}
