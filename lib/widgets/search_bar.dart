/// Виджет строки поиска, используемый на главной странице.
/// Включает иконку меню, текстовое поле для поиска и иконку настроек.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';

/// `SearchBarWidget` - это StatefulWidget, который отображает
/// интерактивную строку поиска в верхней части главной страницы.
class SearchBarWidget extends StatefulWidget {
  /// Конструктор для `SearchBarWidget`.
  const SearchBarWidget({
    super.key,
    this.onMenuPressed,
    this.onSettingsPressed,
    this.onSearchChanged,
  });

  /// Callback для нажатия на иконку меню.
  final VoidCallback? onMenuPressed;

  /// Callback для нажатия на иконку настроек.
  final VoidCallback? onSettingsPressed;

  /// Callback для изменения текста поиска.
  final ValueChanged<String>? onSearchChanged;

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

/// Состояние для виджета `SearchBarWidget`.
class _SearchBarWidgetState extends State<SearchBarWidget> {
  /// Контроллер для текстового поля поиска.
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onMenuPressed,
            child: const Icon(Icons.menu, color: textPrimary, size: 28),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: secondaryBackground,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: textPrimary, fontSize: 16),

                      decoration: InputDecoration(
                        hintText: searchPlaceholder,
                        hintStyle: const TextStyle(
                          color: textMuted,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onSettingsPressed,
                    child: SvgPicture.asset(
                      settingsIconAsset,
                      height: 24,
                      width: 24,
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
}
