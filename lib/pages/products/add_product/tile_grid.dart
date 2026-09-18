// ============================================================
//  Сетка карточек в кабинете товаров (18.09.2026).
// ============================================================
//
// Карточки товаров, способов доставки и сотрудников до этого были шириной
// ровно 150 точек. На узком телефоне два таких столбца оставляли справа
// широкую пустую полосу, а на планшете карточки жались к левому краю.
//
// Здесь ширина считается от той, что есть: столбцов столько, сколько влезает
// карточек не уже [minTile], и они делят ширину поровну. Экран уже — карточки
// уменьшаются, шире — их становится больше, а не остаётся пустота.
//
// Сама карточка о размере ничего не знает: она тянется во всю ширину ячейки,
// а картинку внутри держит квадратной через AspectRatio.

import 'package:flutter/material.dart';

class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 16,
    this.minTile = 150,
    this.maxColumns = 4,
  });

  final List<Widget> children;

  final double spacing;
  final double runSpacing;

  /// Ниже этой ширины карточка перестаёт читаться: название уходит в три
  /// строки, а значок съёмки налезает на угол картинки.
  final double minTile;

  /// Больше четырёх столбцов не делаем даже на широком экране: карточки
  /// становятся мельче значков на них.
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;

        // Два столбца это минимум: один растянутый на всю ширину читается не
        // как карточка, а как строка списка.
        var columns = ((available + spacing) / (minTile + spacing)).floor();

        if (columns < 2) columns = 2;
        if (columns > maxColumns) columns = maxColumns;

        final width = (available - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
