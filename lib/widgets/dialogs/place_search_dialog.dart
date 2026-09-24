// Диалог выбора населённого пункта или улицы поиском (24.09.2026).
//
// Одно поле поиска и список подсказок с пояснением под названием: область и
// район, чтобы отличать одноимённые села. Ничего не подгружает заранее и не
// кеширует: человек вводит название, сервер отвечает.
//
// Заменяет пару «выберите область, потом город» на подаче объявления, в
// контактах и в фильтрах поиска.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/places_service.dart';

class PlaceSearchDialog extends StatefulWidget {
  const PlaceSearchDialog({
    super.key,
    required this.title,
    required this.onSearch,
    this.hint = 'Начните вводить название',
    this.emptyText = 'Ничего не нашлось',
    this.promptText = 'Введите название',
    this.initial = const <PlaceSuggestion>[],
    this.selectedId,
    this.minQueryLength = 2,
  });

  final String title;

  /// Что показывать в списке до ввода: например, улицы выбранного города.
  final List<PlaceSuggestion> initial;

  /// Поиск подсказок по введённой строке.
  final Future<List<PlaceSuggestion>> Function(String query) onSearch;

  final String hint;
  final String emptyText;
  final String promptText;

  /// Уже выбранное значение: подсвечиваем его в списке.
  final int? selectedId;

  /// С какой длины запроса начинаем искать. Сервер адресов просит два символа,
  /// а по готовому списку (номера домов) достаточно одного.
  final int minQueryLength;

  @override
  State<PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<PlaceSearchDialog> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<PlaceSuggestion> _items = const [];
  bool _searching = false;

  /// Номер запроса: ответ на старый ввод не должен перебивать новый.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.initial;
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();

    final query = _searchController.text.trim();

    if (query.length < widget.minQueryLength) {
      setState(() {
        _searching = false;
        _items = widget.initial;
      });
      return;
    }

    setState(() => _searching = true);

    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;

    // Ошибку глотаем: иначе спиннер в поле остался бы навсегда, а человек
    // не понял бы, что подсказки не пришли.
    List<PlaceSuggestion> found;
    try {
      found = await widget.onSearch(query);
    } catch (_) {
      found = const [];
    }

    if (!mounted || id != _requestId) return;

    setState(() {
      _items = found;
      _searching = false;
    });
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
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(color: textSecondary),
                filled: true,
                fillColor: formBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
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

            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      final short = _searchController.text.trim().length < widget.minQueryLength;

      return Center(
        child: Text(
          _searching
              ? 'Ищем...'
              : short
                  ? widget.promptText
                  : widget.emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(color: textSecondary, fontSize: 16),
        ),
      );
    }

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all<Color?>(const Color(0xFF3C3C3C)),
        trackColor: WidgetStateProperty.all<Color?>(
          const Color.fromARGB(255, 43, 23, 26),
        ),
      ),
      child: Scrollbar(
        child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            final selected = widget.selectedId != null && widget.selectedId == item.id;

            return GestureDetector(
              onTap: () => Navigator.of(context).pop(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: selected ? activeIconColor : textPrimary,
                        fontSize: 16,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if ((item.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
