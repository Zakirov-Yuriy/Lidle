// ============================================================
// Экран «Создание кластеров» (макет 09.09.2026).
// ============================================================
//
// НАРИСОВАН, НО НИЧЕГО НЕ СОХРАНЯЕТ, и это осознанно.
//
// Что такое кластер, на 09.09.2026 не решено. Если это количество товара, он
// спорит с полем «Колл. (шт.)» на экране позиции: два поля под одно число
// означают расхождение в остатках, когда продавец поставит в одном месте
// пять, а в другом три. Если это варианты одной вещи (размеры, цвета), то
// это другая таблица и другой экран.
//
// Пока смысл не назван, экран живёт как макет: счётчик работает, кнопка
// «плюс» добавляет строки, но на сервер не уходит ничего. Так честнее, чем
// завести таблицу наугад и переделывать её вместе с уже заведёнными
// товарами.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductClustersScreen extends StatefulWidget {
  const ProductClustersScreen({super.key, required this.positionName});

  /// Название позиции, для которой открыли экран.
  final String positionName;

  @override
  State<ProductClustersScreen> createState() => _ProductClustersScreenState();
}

class _ProductClustersScreenState extends State<ProductClustersScreen> {
  /// Значения счётчиков. Живут только на этом экране.
  final List<int> _clusters = [1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: textPrimary, size: 18),
                  ),
                  const Text(
                    'Создание кластеров',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Отмена',
                        style: TextStyle(color: activeIconColor, fontSize: 16)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Text('Где я нахожусь?',
                  style: TextStyle(color: activeIconColor, fontSize: 14)),
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A3744), height: 1),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Text(
                widget.positionName,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._clusters.asMap().entries.map(
                        (entry) => _counter(entry.key, entry.value),
                      ),
                  GestureDetector(
                    onTap: () => setState(() => _clusters.add(1)),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: formBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add,
                          color: activeIconColor, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Прямо говорим человеку, что экран пока ничего не сохраняет.
            // Молчащая заглушка хуже: он заполнит её и будет искать данные.
            const Padding(
              padding: EdgeInsets.fromLTRB(
                defaultPadding,
                0,
                defaultPadding,
                20,
              ),
              child: Text(
                'Экран в работе: кластеры пока не сохраняются.',
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter(int index, int value) {
    return GestureDetector(
      onTap: () => setState(() => _clusters[index] = value + 1),
      onLongPress: () => setState(() {
        if (_clusters.length > 1) _clusters.removeAt(index);
      }),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$value',
          style: const TextStyle(color: textPrimary, fontSize: 16),
        ),
      ),
    );
  }
}
