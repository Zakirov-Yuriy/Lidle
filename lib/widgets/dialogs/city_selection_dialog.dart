// ============================================================
//  "Диалог выбора города"
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';

class _LetterHeader {
  final String letter;
  _LetterHeader(this.letter);
}

class CitySelectionDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;
  // 🆕 Callback функция для поиска через API
  final Future<List<String>> Function(String query)? onSearchQuery;

  const CitySelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
    this.onSearchQuery,
  });

  @override
  State<CitySelectionDialog> createState() => _CitySelectionDialogState();
}

class _CitySelectionDialogState extends State<CitySelectionDialog> {
  late Set<String> _currentSelectedOptions;
  late List<dynamic> _displayOptions;
  final TextEditingController _searchController = TextEditingController();
  
  // 🆕 Debounce таймер для API поиска
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentSelectedOptions = Set<String>.from(widget.selectedOptions);
    _displayOptions = [];
    _buildDisplayOptions(widget.options);
    _searchController.addListener(_onSearchChanged); // 🔄 Новый обработчик
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// 🆕 Обработчик изменения текста поиска с debounce для API
  void _onSearchChanged() {
    // Отменяем предыдущий таймер
    _debounceTimer?.cancel();
    
    final query = _searchController.text.trim();
    
    // Если запрос пустой, показываем предзагруженные города
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
      });
      _buildDisplayOptions(widget.options);
      return;
    }
    
    // Если есть callback для API поиска — ждем и ищем
    if (widget.onSearchQuery != null) {
      // Показываем индикатор загрузки
      setState(() {
        _isSearching = true;
      });
      
      // Debounce 400ms перед отправкой запроса
      _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
        log.d('🔍 Поиск через API: "$query"');
        try {
          final results = await widget.onSearchQuery!(query);
          log.d('   API вернула ${results.length} результатов');
          
          if (mounted) {
            setState(() {
              _isSearching = false;
            });
            _buildDisplayOptions(results);
          }
        } catch (e) {
          log.d('   ❌ Ошибка поиска: $e');
          if (mounted) {
            setState(() {
              _isSearching = false;
            });
          }
        }
      });
    } else {
      // Без callback — фильтруем клиентский список как раньше
      _filterOptionsLocal(query);
    }
  }

  /// Извлекает основное название города, удаляя префиксы (г., м.о., с. и т.д.)
  String _getCityMainName(String fullCityName) {
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
    List<dynamic> newDisplayOptions = [];
    String? currentLetter;
    List<String> mutableCities = List<String>.from(cities);

    mutableCities.sort((a, b) {
      String mainA = _getCityMainName(a);
      String mainB = _getCityMainName(b);
      return mainA.compareTo(mainB);
    });

    for (var city in mutableCities) {
      String mainName = _getCityMainName(city);
      final firstLetter = mainName[0].toUpperCase();

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

  /// 🆕 Локальный фильтр (если нет API callback)
  void _filterOptionsLocal(String query) {
    final queryLower = query.toLowerCase();
    
    List<String> filteredCities = widget.options.where((option) {
      if (option.toLowerCase().contains(queryLower)) {
        return true;
      }
      
      String mainName = _getCityMainName(option).toLowerCase();
      if (mainName.contains(queryLower)) {
        return true;
      }
      
      return false;
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
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(activeIconColor),
                      ),
                    )
                  : ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: WidgetStateProperty.all<Color?>(
                          const Color(0xFF3C3C3C),
                        ),
                        trackColor: WidgetStateProperty.all<Color?>(
                          const Color.fromARGB(255, 43, 23, 26),
                        ),
                      ),
                      child: Scrollbar(
                        child: _displayOptions.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.isEmpty
                                      ? 'Введите название города'
                                      : 'Город не найден',
                                  style: const TextStyle(
                                    color: textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _displayOptions.length,
                                itemBuilder: (context, index) {
                                  final item = _displayOptions[index];
                                  if (item is _LetterHeader) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
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
                                    final isSelected =
                                        _currentSelectedOptions.contains(
                                      option,
                                    );
                                    return GestureDetector(
                                      onTap: () {
                                        _currentSelectedOptions.clear();
                                        _currentSelectedOptions.add(option);
                                        widget.onSelectionChanged(
                                            _currentSelectedOptions);
                                        Navigator.of(context).pop();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
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
