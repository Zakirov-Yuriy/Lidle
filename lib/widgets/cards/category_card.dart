// ============================================================
//  "Карточка категории"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;

  const CategoryCard({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // log.d('🎯 CategoryCard tapped: ${category.title}');
        onTap?.call();
      },
      child: Container(
        width: categoryCardWidth,
        margin: const EdgeInsets.only(right: 11),
        child: category.imagePath.isEmpty
            ? Container(
                width: categoryCardWidth,
                height: categoryCardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: category.color, width: 1),
                ),
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: category.title,
                          style: TextStyle(
                            color: category.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: category.color,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: _buildImage(),
              ),
      ),
    );
  }

  /// Создает виджет изображения в зависимости от типа пути (URL или asset)
  Widget _buildImage() {
    final imagePath = category.imagePath;

    // Проверяем, является ли это URL (http/https) или локальным путем
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: categoryCardWidth,
        height: categoryCardHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: categoryCardWidth,
            height: categoryCardHeight,
            color: Colors.grey[300],
            child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: categoryCardWidth,
            height: categoryCardHeight,
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    } else {
      // Локальный asset
      return Image.asset(
        imagePath,
        width: categoryCardWidth,
        height: categoryCardHeight,
        fit: BoxFit.cover,
      );
    }
  }
}

