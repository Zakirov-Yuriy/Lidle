// ============================================================
//  "Диалог выбора улицы с поиском"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';

class _SectionHeader {
  final String title;
  _SectionHeader(this.title);
}

class StreetSelectionDialog extends StatefulWidget {
  final String title;
  final Map<String, List<String>>? groupedOptions;
  final List<String>? options;
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;
  final Future<List<String>> Function(String)? onSearchQuery;

  const StreetSelectionDialog({
    super.key,
    required this.title,
    this.groupedOptions,
    this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
    this.onSearchQuery,
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
    
    // 🔍 Логирование загруженных улиц
    if (widget.options != null) {
      log.d('📍 [STREET DIALOG] Открыт диалог с ${widget.options!.length} улицами');
      log.d('   Улицы:');
      for (var i = 0; i < widget.options!.length && i < 20; i++) {
        log.d('   - ${widget.options![i]}');
      }
      if (widget.options!.length > 20) {
        log.d('   ... и ещё ${widget.options!.length - 20}');
      }
    } else if (widget.groupedOptions != null) {
      final totalStreets = widget.groupedOptions!.values.fold<int>(0, (prev, curr) => prev + curr.length);
      log.d('📍 [STREET DIALOG] Открыт диалог с ${totalStreets} улицами (${widget.groupedOptions!.length} групп)');
    }
    
    if (widget.onSearchQuery != null) {
      log.d('📍 [STREET DIALOG] API поиск включен');
    }
    
    if (widget.groupedOptions != null) {
      _buildDisplayOptions(widget.groupedOptions!);
    } else if (widget.options != null) {
      _buildDisplayOptionsFromList(widget.options!);
    }
    _searchController.addListener(_filterOptions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOptions);
    _searchController.dispose();
    super.dispose();
  }

  /// Извлекает основное название улицы, удаляя префиксы (ул., пр., пер. и т.д.)
  String _getStreetMainName(String fullStreetName) {
    String mainName = fullStreetName
        .replaceAll(RegExp(r'^ул\.\s+'), '')
        .replaceAll(RegExp(r'^улица\s+'), '')
        .replaceAll(RegExp(r'^пр\.\s+'), '')
        .replaceAll(RegExp(r'^проспект\s+'), '')
        .replaceAll(RegExp(r'^пер\.\s+'), '')
        .replaceAll(RegExp(r'^переулок\s+'), '')
        .replaceAll(RegExp(r'^бульвар\s+'), '')
        .replaceAll(RegExp(r'^б-р\s+'), '')
        .replaceAll(RegExp(r'^площадь\s+'), '')
        .replaceAll(RegExp(r'^пл\.\s+'), '')
        .replaceAll(RegExp(r'^шоссе\s+'), '')
        .replaceAll(RegExp(r'^дорога\s+'), '')
        .replaceAll(RegExp(r'^тракт\s+'), '')
        .replaceAll(RegExp(r'^набережная\s+'), '')
        .replaceAll(RegExp(r'^набер\.\s+'), '')
        .trim();
    return mainName.isNotEmpty ? mainName : fullStreetName;
  }

  // Для списка улиц (новый формат)
  void _buildDisplayOptionsFromList(List<String> streets, {bool addSections = true}) {
    List<dynamic> newDisplayOptions = [];
    String? currentLetter;
    List<String> mutableStreets = List<String>.from(streets);

    mutableStreets.sort((a, b) {
      String mainA = _getStreetMainName(a);
      String mainB = _getStreetMainName(b);
      return mainA.compareTo(mainB);
    });

    for (var street in mutableStreets) {
      // Добавляем секции только если addSections=true (когда нет поиска)
      if (addSections) {
        String mainName = _getStreetMainName(street);
        final firstLetter = mainName[0].toUpperCase();

        if (firstLetter != currentLetter) {
          newDisplayOptions.add(_SectionHeader(firstLetter));
          currentLetter = firstLetter;
        }
      }
      newDisplayOptions.add(street);
    }
    setState(() {
      _displayOptions = newDisplayOptions;
    });
  }

  // Для сгруппированных улиц (старый формат)
  void _buildDisplayOptions(Map<String, List<String>> groupedStreets) {
    List<dynamic> newDisplayOptions = [];
    final sortedSectionKeys = groupedStreets.keys.toList()..sort();

    for (var sectionKey in sortedSectionKeys) {
      newDisplayOptions.add(_SectionHeader(sectionKey));
      List<String> streetsInSection = List<String>.from(
        groupedStreets[sectionKey]!,
      );
      streetsInSection.sort();
      newDisplayOptions.addAll(streetsInSection);
    }

    setState(() {
      _displayOptions = newDisplayOptions;
    });
  }

  void _filterOptions() async {
    final query = _searchController.text.toLowerCase();
    
    // 🔍 Логирование поиска улиц
    if (query.isNotEmpty) {
      log.d('🔍 [STREET SEARCH] Пользователь ищет: "$query"');
    }

    // 🆕 Если есть onSearchQuery callback - используем API поиск
    if (query.isNotEmpty && widget.onSearchQuery != null) {
      log.d('   → Searching via API...');
      try {
        final apiResults = await widget.onSearchQuery!(query);
        log.d('   ✅ API results: ${apiResults.length} улиц');
        
        // 🎯 Фильтруем API результаты - ТОЛЬКО точные совпадения по началу названия
        List<String> filteredApiResults = apiResults
            .where((street) {
              final mainName = _getStreetMainName(street).toLowerCase();
              return mainName.startsWith(query);
            })
            .toList();
        
        log.d('   ✅ Отфильтровано: ${filteredApiResults.length} улиц (было ${apiResults.length})');
        if (filteredApiResults.isNotEmpty) {
          for (var i = 0; i < filteredApiResults.length && i < 10; i++) {
            log.d('   ✓ ${filteredApiResults[i]}');
          }
          if (filteredApiResults.length > 10) {
            log.d('   ... и ещё ${filteredApiResults.length - 10}');
          }
        }
        
        // 🎯 При поиске НЕ добавляем секции заголовков
        _buildDisplayOptionsFromList(filteredApiResults, addSections: false);
        return;
      } catch (e) {
        log.e('   ❌ API search failed: $e, falling back to local filtering');
      }
    }

    // Локальная фильтрация (fallback или когда нет API callback)
    if (widget.groupedOptions != null) {
      // Фильтр для сгруппированных улиц
      Map<String, List<String>> filteredGroupedStreets = {};

      widget.groupedOptions!.forEach((sectionKey, streets) {
        // 🎯 ТОЛЬКО точные совпадения по началу основного названия
        final filteredStreets = streets.where((street) {
          final mainName = _getStreetMainName(street).toLowerCase();
          return mainName.startsWith(query);
        }).toList();
        
        if (filteredStreets.isNotEmpty) {
          filteredGroupedStreets[sectionKey] = filteredStreets;
        }
      });

      if (query.isNotEmpty) {
        log.d('   Найдено ${filteredGroupedStreets.values.fold<int>(0, (prev, curr) => prev + curr.length)} результатов');
      }

      _buildDisplayOptions(filteredGroupedStreets);
    } else if (widget.options != null) {
      // Фильтр для списка улиц - 🎯 ТОЛЬКО точные совпадения по началу
      List<String> exactMatches = widget.options!
          .where((option) {
            final mainName = _getStreetMainName(option).toLowerCase();
            return mainName.startsWith(query);
          })
          .toList();
      
      if (query.isNotEmpty) {
        log.d('   Найдено ${exactMatches.length} результатов');
        for (var i = 0; i < exactMatches.length && i < 10; i++) {
          log.d('   ✅ ${exactMatches[i]}');
        }
        if (exactMatches.length > 10) {
          log.d('   ... и ещё ${exactMatches.length - 10}');
        }
      }
      
      // 🎯 При поиске НЕ добавляем секции заголовков - только отсортированный список
      _buildDisplayOptionsFromList(exactMatches, addSections: query.isEmpty);
    }
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
