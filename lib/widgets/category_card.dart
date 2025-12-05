/// Виджет карточки категории, используемый на главной странице.
/// Отображает изображение категории и ее заголовок.
import 'package:flutter/material.dart';
import '../models/home_models.dart';
import '../constants.dart';

/// `CategoryCard` - это StatelessWidget, который отображает
/// отдельную карточку категории с изображением и заголовком.
class CategoryCard extends StatelessWidget {
  /// Объект [Category], содержащий данные для отображения.
  final Category category;

  /// Callback, вызываемый при нажатии на категорию.
  final VoidCallback? onTap;

  /// Конструктор для `CategoryCard`.
  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: categoryCardWidth,
        margin: const EdgeInsets.only(right: 11),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                category.imagePath,
                width: categoryCardWidth,
                height: categoryCardHeight,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 15,
              left: 10,
              child: Text(
                category.title,
                style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  shadows: [],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
