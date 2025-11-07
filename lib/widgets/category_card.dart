import 'package:flutter/material.dart';
import '../models/home_models.dart';
import '../constants.dart';

class CategoryCard extends StatelessWidget {
  final Category category;

  const CategoryCard({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: categoryCardWidth,
      margin: const EdgeInsets.only(right: 11),
      child: Stack(
        children: [
          // Изображение
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              category.imagePath,
              width: categoryCardWidth,
              height: categoryCardHeight,
              fit: BoxFit.cover,
            ),
          ),
          // Текст вверху слева
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
    );
  }
}
