import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/dynamic_filter/dynamic_filter.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';

// ============================================================
// "Виджет: Экран подкатегорий недвижимости (квартиры)"
// ============================================================

class RealEstateApartmentsScreen extends StatefulWidget {
  final String subcategory;

  const RealEstateApartmentsScreen({super.key, required this.subcategory});

  @override
  State<RealEstateApartmentsScreen> createState() =>
      _RealEstateApartmentsScreenState();
}

class _RealEstateApartmentsScreenState
    extends State<RealEstateApartmentsScreen> {
  List<Category> _advertTypes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdvertTypes();
  }

  Future<void> _loadAdvertTypes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await HiveService.getUserData('token');

      // Ищем конечные категории для данной подкатегории
      // Используем subcategory как поисковый запрос
      final searchResult = await ApiService.searchCategories(
        catalogId: 1, // Недвижимость
        query: widget.subcategory,
        token: token,
      );

      print('Found advert types: ${searchResult.data.length}');
      searchResult.data.forEach(
        (category) => print('Advert type: ${category.name}'),
      );

      setState(() {
        _advertTypes = searchResult.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 23, top: 20),
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
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: activeIconColor,
                        size: 16,
                      ),
                    ),
                    const Text(
                      'Назад',
                      style: TextStyle(
                        color: activeIconColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: activeIconColor),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ошибка загрузки: $_error',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAdvertTypes,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(left: 25.0, right: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Недвижимость: ${widget.subcategory == 'Недвижимость за рубежом' ? 'За рубежом' : widget.subcategory}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _advertTypes.length + 1,
                            itemBuilder: (context, index) {
                              if (index < _advertTypes.length) {
                                final advertType = _advertTypes[index];
                                return Column(
                                  children: [
                                    _buildOptionTile(context, advertType),
                                    if (index < _advertTypes.length - 1)
                                      const Divider(
                                        color: Colors.white24,
                                        height: 0.9,
                                      ),
                                  ],
                                );
                              } else {
                                return const Divider(
                                  color: Colors.white24,
                                  height: 0.9,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // "Виджет: Построение плитки опции (продажа/аренда квартир)"
  // ============================================================
  Widget _buildOptionTile(BuildContext context, Category advertType) {
    final title = advertType.name;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          onTap: () {
            // Все категории недвижимости теперь используют динамический фильтр
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DynamicFilter(category: advertType),
              ),
            );
          },
        ),
        const Divider(color: Colors.white24, height: 0.9),
      ],
    );
  }
}
