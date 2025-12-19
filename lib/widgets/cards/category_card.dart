// ============================================================
//  "Карточка категории"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/constants.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;

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
            if (category.imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  category.imagePath,
                  width: categoryCardWidth,
                  height: categoryCardHeight,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: categoryCardWidth,
                height: categoryCardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: category.color,
                    width: 1,
                  ),
                ),
              ),
            Positioned(
              top: 15,
              left: 10,
              child: category.imagePath.isEmpty
                  ? RichText(
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
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: category.color,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      category.title,
                      style: TextStyle(
                        color: const Color.fromARGB(255, 0, 0, 0),
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
