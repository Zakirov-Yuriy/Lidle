// ============================================================
//  "Диалог выбора города"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class _LetterHeader {
  final String letter;
  _LetterHeader(this.letter);
}

class CitySelectionDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;

  const CitySelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
  });

  @override
  State<CitySelectionDialog> createState() => _CitySelectionDialogState();
}

class _CitySelectionDialogState extends State<CitySelectionDialog> {
  late Set<String> _currentSelectedOptions;
  late List<dynamic> _displayOptions;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSelectedOptions = Set<String>.from(widget.selectedOptions);
    _displayOptions = []; // Инициализируем пустой список
    print('🔍 CitySelectionDialog initState:');
    print('   - widget.options.length: ${widget.options.length}');
    print('   - widget.options значения: ${widget.options}');
    _buildDisplayOptions(widget.options); // Initial build
    _searchController.addListener(_filterOptions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOptions);
    _searchController.dispose();
    super.dispose();
  }

  /// Извлекает основное название города, удаляя префиксы (г., м.о., с. и т.д.)
  String _getCityMainName(String fullCityName) {
    // Удаляем префиксы: "г. ", "м.о. ", "с. ", "г.о. ", "пгт. " и т.д.
    String mainName = fullCityName
        .replaceAll(RegExp(r'^г\.\s+'), '')
        .replaceAll(RegExp(r'^м\.о\.\s+'), '')
        .replaceAll(RegExp(r'^с\.\s+'), '')
        .replaceAll(RegExp(r'^г\.о\.\s+'), '')
        .replaceAll(RegExp(r'^пгт\.\s+'), '')
        .replaceAll(RegExp(r'^пс\.\s+'), '')
        .replaceAll(RegExp(r'^п\.\s+'), '')
        .trim();
    return mainName.isNotEmpty ? mainName : fullCityName;
  }

  void _buildDisplayOptions(List<String> cities) {
    print('🏗️ _buildDisplayOptions called:');
    print('   - cities.length: ${cities.length}');
    print('   - cities (first 10): ${cities.take(10).toList()}');
    
    List<dynamic> newDisplayOptions = [];
    String? currentLetter;
    List<String> mutableCities = List<String>.from(cities);

    // Сортируем по основному названию города, игнорируя префиксы
    mutableCities.sort((a, b) {
      String mainA = _getCityMainName(a);
      String mainB = _getCityMainName(b);
      return mainA.compareTo(mainB);
    });

    for (var city in mutableCities) {
      // Берем первую букву основного названия для группировки
      String mainName = _getCityMainName(city);
      final firstLetter = mainName[0].toUpperCase();

      if (firstLetter != currentLetter) {
        newDisplayOptions.add(_LetterHeader(firstLetter));
        currentLetter = firstLetter;
      }
      newDisplayOptions.add(city);
    }
    print('✅ newDisplayOptions.length: ${newDisplayOptions.length}');
    setState(() {
      _displayOptions = newDisplayOptions;
      print('   📝 После setState: _displayOptions.length = ${_displayOptions.length}');
    });
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    List<String> filteredCities = widget.options.where((option) {
      return option.toLowerCase().contains(query);
    }).toList();
    _buildDisplayOptions(filteredCities);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222E3A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 13, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minHeight: 300,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 23),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск',
                hintStyle: const TextStyle(color: textSecondary),
                filled: true,
                fillColor: formBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all<Color?>(
                    const Color(0xFF3C3C3C),
                  ),
                  trackColor: WidgetStateProperty.all<Color?>(
                    const Color.fromARGB(255, 43, 23, 26),
                  ),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    itemCount: _displayOptions.length,
                    itemBuilder: (context, index) {
                      final item = _displayOptions[index];
                      if (item is _LetterHeader) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            item.letter,
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      } else {
                        final option = item as String;
                        final isSelected = _currentSelectedOptions.contains(
                          option,
                        );
                        return GestureDetector(
                          onTap: () {
                            _currentSelectedOptions.clear();
                            _currentSelectedOptions.add(option);
                            widget.onSelectionChanged(_currentSelectedOptions);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isSelected
                                    ? activeIconColor
                                    : textPrimary,
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size(127, 35),
                    side: const BorderSide(color: activeIconColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onSelectionChanged(_currentSelectedOptions);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Выбрать',
                    style: TextStyle(color: activeIconColor, fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
