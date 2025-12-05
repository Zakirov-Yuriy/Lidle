// ============================================================
//  "Диалог выбора улицы"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class _SectionHeader {
  final String title;
  _SectionHeader(this.title);
}

class StreetSelectionDialog extends StatefulWidget {
  final String title;
  final Map<String, List<String>> groupedOptions;
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;

  const StreetSelectionDialog({
    super.key,
    required this.title,
    required this.groupedOptions,
    required this.selectedOptions,
    required this.onSelectionChanged,
  });

  @override
  State<StreetSelectionDialog> createState() => _StreetSelectionDialogState();
}

class _StreetSelectionDialogState extends State<StreetSelectionDialog> {
  late Set<String> _currentSelectedOptions;
  late List<dynamic> _displayOptions;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSelectedOptions = Set<String>.from(widget.selectedOptions);
    _buildDisplayOptions(widget.groupedOptions);
    _searchController.addListener(_filterOptions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOptions);
    _searchController.dispose();
    super.dispose();
  }

  void _buildDisplayOptions(Map<String, List<String>> groupedStreets) {
    List<dynamic> newDisplayOptions = [];

    final sortedSectionKeys = groupedStreets.keys.toList()..sort();

    for (var sectionKey in sortedSectionKeys) {
      newDisplayOptions.add(_SectionHeader(sectionKey));
      List<String> streetsInSection = List<String>.from(groupedStreets[sectionKey]!);
      streetsInSection.sort();
      newDisplayOptions.addAll(streetsInSection);
    }

    setState(() {
      _displayOptions = newDisplayOptions;
    });
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    Map<String, List<String>> filteredGroupedStreets = {};

    widget.groupedOptions.forEach((sectionKey, streets) {
      final filteredStreets = streets.where((street) {
        return street.toLowerCase().contains(query);
      }).toList();
      if (filteredStreets.isNotEmpty) {
        filteredGroupedStreets[sectionKey] = filteredStreets;
      }
    });

    _buildDisplayOptions(filteredGroupedStreets);
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
                  thumbColor: WidgetStateProperty.all<Color?>(const Color(0xFF3C3C3C)),
                  trackColor: WidgetStateProperty.all<Color?>(const Color.fromARGB(255, 43, 23, 26)),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _displayOptions.length,
                    itemBuilder: (context, index) {
                      final item = _displayOptions[index];
                      if (item is _SectionHeader) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            item.title,
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
                            setState(() {});
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
