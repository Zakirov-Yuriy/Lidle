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
  late List<dynamic> _displayOptions; // Changed to dynamic to hold both cities and headers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSelectedOptions = Set<String>.from(widget.selectedOptions);
    _buildDisplayOptions(widget.options); // Initial build
    _searchController.addListener(_filterOptions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOptions);
    _searchController.dispose();
    super.dispose();
  }

  void _buildDisplayOptions(List<String> cities) {
    List<dynamic> newDisplayOptions = [];
    String? currentLetter;
    List<String> mutableCities = List<String>.from(cities); // Create a mutable copy
    mutableCities.sort((a, b) => a.compareTo(b)); // Ensure sorted for grouping

    for (var city in mutableCities) { // Use the mutable copy
      final firstLetter = city[0].toUpperCase();
      if (firstLetter != currentLetter) {
        newDisplayOptions.add(_LetterHeader(firstLetter));
        currentLetter = firstLetter;
      }
      newDisplayOptions.add(city);
    }
    setState(() {
      _displayOptions = newDisplayOptions;
    });
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    List<String> filteredCities = widget.options.where((option) {
      return option.toLowerCase().contains(query);
    }).toList();
    _buildDisplayOptions(filteredCities); // Rebuild with filtered cities
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222E3A), // Match SelectionDialog
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Match SelectionDialog
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 13, 20), // Match SelectionDialog
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton( // Close button on the top right
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
                    fontSize: 18, // Match SelectionDialog
                    fontWeight: FontWeight.bold, // Match SelectionDialog
                  ),
                ),
              ],
            ),
            const SizedBox(height: 23), // Match SelectionDialog
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
            Flexible( // Use Flexible instead of Expanded for better sizing with SingleChildScrollView
              child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all<Color?>(const Color(0xFF3C3C3C)),
                  trackColor: WidgetStateProperty.all<Color?>(const Color.fromARGB(255, 43, 23, 26)),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _displayOptions.length, // Use _displayOptions
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
                        final isSelected = _currentSelectedOptions.contains(option);
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
                      }
                    },
                  ),
                ),
              ),
            ), // Закрывающая скобка для Flexible
            const SizedBox(height: 20), // Match SelectionDialog
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Match SelectionDialog
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary, // Match SelectionDialog
                      fontSize: 16,
                      decoration: TextDecoration.underline, // Match SelectionDialog
                      decorationColor: textPrimary, // Match SelectionDialog
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton( // Change to OutlinedButton
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size(127, 35), // Match SelectionDialog
                    side: const BorderSide(color: activeIconColor), // Match SelectionDialog
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Match SelectionDialog
                    ),
                  ),
                  onPressed: () {
                    widget.onSelectionChanged(_currentSelectedOptions);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Готово', // Change text to 'Готово'
                    style: TextStyle(color: activeIconColor, fontSize: 16), // Match SelectionDialog
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
