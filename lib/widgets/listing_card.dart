import 'package:flutter/material.dart';
import '../models/home_models.dart';
import '../constants.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;

  const ListingCard({
    super.key,
    required this.listing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;

        // FIX: немного уменьшаем долю высоты под изображение
        double imageProportion = cardWidth < 140 ? 0.50 : 0.58; // было 0.604
        final imageHeight = cardHeight * imageProportion;

        // Масштаб шрифтов относительно базовой высоты 263
        final scale = cardHeight / 263;
        final titleFontSize = 14 * scale;
        final priceFontSize = 16 * scale;
        final locationFontSize = 13 * scale;
        final dateFontSize = 12 * scale;
        final iconSize = 16 * scale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение
            SizedBox(
              width: double.infinity,
              height: imageHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Image.asset(
                  listing.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF374B5C),
                      child: Icon(
                        Icons.image,
                        color: textMuted,
                        size: 50 * scale,
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: 8 * scale),

            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название и избранное
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1, // FIX: только одна строка
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4 * scale),
                      Icon(
                        Icons.favorite_border,
                        color: textPrimary,
                        size: iconSize,
                      ),
                    ],
                  ),

                  SizedBox(height: 3 * scale), // FIX: было 4
                  // Цена
                  Text(
                    listing.price,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  SizedBox(height: 3 * scale), // FIX: было 4
                  // Адрес
                  Text(
                    listing.location,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: locationFontSize,
                    ),
                    maxLines: 1, // FIX: было 2
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 1 * scale),

                  // Дата
                  Text(
                    listing.date,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: dateFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
