// ============================================================
//  "Диалог выбора номера дома с поиском"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class BuildingSelectionDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;

  const BuildingSelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
  });

  @override
  State<BuildingSelectionDialog> createState() =>
      _BuildingSelectionDialogState();
}

class _BuildingSelectionDialogState extends State<BuildingSelectionDialog> {
  late Set<String> _currentSelectedOptions;
  late List<String> _displayOptions;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSelectedOptions = Set<String>.from(widget.selectedOptions);
    _buildDisplayOptions(widget.options);
    _searchController.addListener(_filterOptions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOptions);
    _searchController.dispose();
    super.dispose();
  }

  /// Извлекает основной номер дома, удаляя префиксы (д., дом и т.д.)
  String _getBuildingMainNumber(String fullBuildingName) {
    // Удаляем префиксы: "д. ", "дом " и т.д.
    String mainName = fullBuildingName
        .replaceAll(RegExp(r'^д\.\s+'), '')
        .replaceAll(RegExp(r'^дом\s+'), '')
        .trim();
    return mainName.isNotEmpty ? mainName : fullBuildingName;
  }

  void _buildDisplayOptions(List<String> buildings) {
    List<String> mutableBuildings = List<String>.from(buildings);

    // Сортируем по основному номеру дома
    mutableBuildings.sort((a, b) {
      String mainA = _getBuildingMainNumber(a);
      String mainB = _getBuildingMainNumber(b);
      // Попытаемся сортировать численно, если это числа
      int? numA = int.tryParse(mainA);
      int? numB = int.tryParse(mainB);
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }
      // Иначе сортируем как строки
      return mainA.compareTo(mainB);
    });

    setState(() {
      _displayOptions = mutableBuildings;
    });
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    List<String> filteredBuildings = widget.options
        .where((option) => option.toLowerCase().contains(query))
        .toList();
    _buildDisplayOptions(filteredBuildings);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222E3A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 13, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  textAlign: TextAlign.center,
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
            Flexible(
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
                    shrinkWrap: true,
                    itemCount: _displayOptions.length,
                    itemBuilder: (context, index) {
                      final option = _displayOptions[index];
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
                              color: isSelected ? activeIconColor : textPrimary,
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
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
