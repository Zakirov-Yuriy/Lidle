// ============================================================
//  "Диалог выбора" (с поддержкой поиска через API)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/token_service.dart';
import '../components/custom_checkbox.dart';
import '../components/custom_radio_button.dart';

class SelectionDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selectedOptions;
  final Function(Set<String>) onSelectionChanged;
  final bool allowMultipleSelection;
  // 🆕 Callback функция для поиска через API (опционально)
  final Future<List<String>> Function(String query)? onSearchQuery;

  const SelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
    this.allowMultipleSelection = true,
    this.onSearchQuery,
  });

  @override
  _SelectionDialogState createState() => _SelectionDialogState();
}

class _SelectionDialogState extends State<SelectionDialog> {
  late Set<String> _tempSelectedOptions;
  late TextEditingController _searchController;
  late List<String> _filteredOptions;
  late List<String> _allOptions;
  
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tempSelectedOptions = widget.selectedOptions;
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _allOptions = List<String>.from(widget.options);
    _filteredOptions = List<String>.from(widget.options);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// 🆕 Очистить поисковый запрос от пунктуации и спецсимволов
  /// Оставляем только буквы (любого алфавита), цифры, пробелы и дефис
  String _cleanSearchQuery(String query) {
    return query
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 🆕 Получить "чистое" имя опции (без региона в скобках)
  String _getCleanOptionName(String option) {
    // Если есть "(регион)" в конце, убираем его
    final match = RegExp(r'^(.+?)\s*\(.*?\)$').firstMatch(option);
    if (match != null) {
      return match.group(1)?.trim() ?? option;
    }
    return option;
  }

  /// Обработчик изменения текста поиска с debounce
  void _onSearchChanged() {
    _debounceTimer?.cancel();

    // 🆕 Очищаем запрос от пунктуации
    final query = _cleanSearchQuery(_searchController.text);

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredOptions = List<String>.from(_allOptions);
      });
      return;
    }

    // 🆕 Сразу показываем локальные результаты для мгновенного отклика
    _filterOptionsLocal(query);

    // Если запрос < 3 символов — API не вызываем
    if (query.length < 3) {
      log.d('🔍 Локальный поиск: "$query"');
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      // 🆕 Если передан callback для поиска, используем его
      if (widget.onSearchQuery != null) {
        await _searchViaCallback(query);
      } else {
        // Fallback на локальный поиск или API
        if (widget.title.toLowerCase().contains('город') || 
            widget.title.toLowerCase().contains('регион') ||
            widget.title.toLowerCase().contains('улиц')) {
          await _searchViaAPI(query);
        } else {
          _filterOptionsLocal(query);
          setState(() => _isSearching = false);
        }
      }
    });
  }

  /// Фильтровать опции локально
  void _filterOptionsLocal(String query) {
    final queryLower = query.toLowerCase();
    setState(() {
      _filteredOptions = _allOptions
          .where((option) {
            final cleanName = _getCleanOptionName(option).toLowerCase();
            final fullName = option.toLowerCase();
            return cleanName.contains(queryLower) || fullName.contains(queryLower);
          })
          .toList();
    });
  }

  /// 🆕 Поиск через переданный callback
  Future<void> _searchViaCallback(String query) async {
    try {
      final searchResults = <String>{};
      final queryLower = query.toLowerCase();

      // Вызываем переданный callback для поиска
      final items = await widget.onSearchQuery!(query);

      log.d('🔍 Поиск API (via callback): "$query"');
      log.d('   ✅ Callback вернул ${items.length} результатов');

      for (final item in items) {
        final cleanName = _getCleanOptionName(item).toLowerCase();
        final fullName = item.toLowerCase();
        final matches = cleanName.contains(queryLower) || fullName.contains(queryLower);

        if (matches) {
          searchResults.add(item);
        }
      }

      // Также добавляем локальные совпадения
      for (final option in _allOptions) {
        if (searchResults.contains(option)) continue;
        final cleanName = _getCleanOptionName(option).toLowerCase();
        if (cleanName.contains(queryLower) || option.toLowerCase().contains(queryLower)) {
          searchResults.add(option);
        }
      }

      final resultsList = searchResults.toList();
      log.d('   ✅ Найдено ${resultsList.length} результатов');

      if (mounted) {
        setState(() {
          _isSearching = false;
          _filteredOptions = resultsList;
        });
      }
    } catch (e) {
      log.d('   ❌ Ошибка поиска (callback): $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// 🆕 Поиск через AddressService API
  Future<void> _searchViaAPI(String query) async {
    try {
      final searchResults = <String>{};
      final queryLower = query.toLowerCase();

      final token = TokenService.currentToken;

      log.d('🔍 Поиск API: "$query"');

      try {
        final response = await AddressService.searchAddresses(
          query: query,
          token: token,
        );

        int matchCount = 0;
        for (final result in response.data) {
          String? itemName;

          // Проверяем разные типы результатов (city, region, street, building)
          if (result.city != null) {
            itemName = result.city!.name;
          } else if (result.region != null) {
            itemName = result.region!.name;
          } else if (result.street != null) {
            itemName = result.street!.name;
          }

          if (itemName != null) {
            final cleanName = _getCleanOptionName(itemName).toLowerCase();
            final fullName = itemName.toLowerCase();
            final matches = cleanName.contains(queryLower) || fullName.contains(queryLower);

            if (matches) {
              searchResults.add(itemName);
              matchCount++;
            }
          }
        }

        log.d('   ✅ API вернул $matchCount совпадений');
      } catch (e) {
        log.d('   ⚠️  Ошибка API поиска: $e');
      }

      // Также добавляем локальные совпадения из исходного списка
      for (final option in _allOptions) {
        if (searchResults.contains(option)) continue;
        final cleanName = _getCleanOptionName(option).toLowerCase();
        if (cleanName.contains(queryLower) || option.toLowerCase().contains(queryLower)) {
          searchResults.add(option);
        }
      }

      final resultsList = searchResults.toList();
      log.d('   ✅ Всего найдено ${resultsList.length} результатов (API + локально)');

      if (mounted) {
        setState(() {
          _isSearching = false;
          _filteredOptions = resultsList;
        });
      }
    } catch (e) {
      log.d('   ❌ Ошибка поиска: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222E3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 13, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minHeight: 300,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 🔘 КНОПКА ЗАКРЫТИЯ
            IconButton(
              icon: const Icon(Icons.close, color: textPrimary),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),

            // 📌 ЗАГОЛОВОК
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

            // 🔍 ПОЛЕ ПОИСКА
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
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(activeIconColor),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 15),

            // 📋 СПИСОК ОПЦИЙ
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _filteredOptions.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Нет опций'
                                  : 'Не найдено',
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          )
                        ]
                      : _filteredOptions
                          .map((option) => _buildCheckbox(option))
                          .toList(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔘 КНОПКИ
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(127, 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
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
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: activeIconColor),
                    minimumSize: const Size(127, 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onSelectionChanged(_tempSelectedOptions);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Готово',
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

  Widget _buildCheckbox(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (widget.allowMultipleSelection) {
                    if (_tempSelectedOptions.contains(title)) {
                      _tempSelectedOptions.remove(title);
                    } else {
                      _tempSelectedOptions.add(title);
                    }
                  } else {
                    // For single selection, clear existing and add new
                    if (_tempSelectedOptions.contains(title)) {
                      _tempSelectedOptions.remove(title);
                    } else {
                      _tempSelectedOptions.clear();
                      _tempSelectedOptions.add(title);
                    }
                  }
                });
              },
              child: Text(
                title,
                style: const TextStyle(color: textPrimary, fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (widget.allowMultipleSelection)
            // 🔲 Множественный выбор - CHECKBOXES
            CustomCheckbox(
              value: _tempSelectedOptions.contains(title),
              onChanged: (bool value) {
                setState(() {
                  if (value) {
                    _tempSelectedOptions.add(title);
                  } else {
                    _tempSelectedOptions.remove(title);
                  }
                });
              },
            )
          else
            // 🔘 Одиночный выбор - RADIO BUTTONS
            CustomRadioButton<String>(
              value: title,
              groupValue: _tempSelectedOptions.isNotEmpty
                  ? _tempSelectedOptions.first
                  : null,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _tempSelectedOptions.clear();
                    _tempSelectedOptions.add(value);
                  });
                } else if (value == null) {
                  setState(() {
                    _tempSelectedOptions.remove(title);
                  });
                }
              },
              selectedBorderColor: const Color(0xFF888888),
              unselectedBorderColor: const Color(0xFF888888),
              selectedFillColor: const Color(0xFF00A6FF),
            ),
        ],
      ),
    );
  }
}
