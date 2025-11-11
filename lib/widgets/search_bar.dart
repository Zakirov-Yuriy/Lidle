/// Виджет строки поиска, используемый на главной странице.
/// Включает иконку меню, текстовое поле для поиска и иконку настроек.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';

/// `SearchBarWidget` - это StatelessWidget, который отображает
/// строку поиска в верхней части главной страницы.
class SearchBarWidget extends StatelessWidget {
  /// Конструктор для `SearchBarWidget`.
  const SearchBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          const Icon(Icons.menu, color: textPrimary, size: 28),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: secondaryBackground,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      searchPlaceholder,
                      style: const TextStyle(color: textMuted, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    settingsIconAsset,
                    height: 24,
                    width: 24,
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
