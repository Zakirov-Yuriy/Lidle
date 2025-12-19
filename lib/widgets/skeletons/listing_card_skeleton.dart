import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;

        double imageProportion = cardWidth < 140 ? 0.50 : 0.58;
        final imageHeight = cardHeight * imageProportion;

        final scale = cardHeight / 263;

        return Shimmer.fromColors(
          baseColor: const Color(0xFF374B5C),
          highlightColor: const Color(0xFF4A5C6A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Имитация изображения
              Container(
                width: double.infinity,
                height: imageHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A5C6A),
                  borderRadius: BorderRadius.circular(5 * scale),
                ),
              ),

              SizedBox(height: 18 * scale),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Имитация заголовка и иконки избранного
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Имитация заголовка
                        Expanded(
                          child: Container(
                            height: 14 * scale,
                            color: const Color(0xFF4A5C6A),
                          ),
                        ),
                        SizedBox(width: 4 * scale),
                        // Имитация иконки избранного
                        Container(
                          width: 18 * scale,
                          height: 18 * scale,
                          color: const Color(0xFF4A5C6A),
                        ),
                      ],
                    ),

                    SizedBox(height: 8 * scale),

                    // Имитация цены
                    Container(
                      width: 100 * scale,
                      height: 16 * scale,
                      color: const Color(0xFF4A5C6A),
                    ),

                    SizedBox(height: 3 * scale),

                    // Имитация локации
                    Container(
                      width: 80 * scale,
                      height: 13 * scale,
                      color: const Color(0xFF4A5C6A),
                    ),

                    SizedBox(height: 1 * scale),

                    // Имитация даты
                    Container(
                      width: 60 * scale,
                      height: 12 * scale,
                      color: const Color(0xFF4A5C6A),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
