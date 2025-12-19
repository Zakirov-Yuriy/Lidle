import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lidle/constants.dart';

class CategoryCardSkeleton extends StatelessWidget {
  const CategoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF374B5C),
      highlightColor: const Color(0xFF4A5C6A),
      child: Container(
        width: categoryCardWidth,
        height: categoryCardHeight,
        margin: const EdgeInsets.only(right: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF374B5C),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Stack(
          children: [
            // Имитация изображения
            Container(
              width: categoryCardWidth,
              height: categoryCardHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF4A5C6A),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Имитация текста
            Positioned(
              top: 15,
              left: 10,
              child: Container(
                width: 80,
                height: 16,
                color: const Color(0xFF4A5C6A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
