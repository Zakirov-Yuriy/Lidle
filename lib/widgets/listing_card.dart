import 'package:flutter/material.dart';
import '../models/home_models.dart';
import '../constants.dart';
import '../hive_service.dart';

/// `ListingCard` - это StatefulWidget, который отображает
/// отдельную карточку объявления с возможностью добавления в избранное.
class ListingCard extends StatefulWidget {
  /// Объект [Listing], содержащий данные для отображения.
  final Listing listing;

  /// Конструктор для `ListingCard`.
  const ListingCard({
    super.key,
    required this.listing,
  });

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = HiveService.getFavorites().contains(widget.listing.id);
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    HiveService.toggleFavorite(widget.listing.id);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;

        double imageProportion = cardWidth < 140 ? 0.50 : 0.58;
        final imageHeight = cardHeight * imageProportion;

        final scale = cardHeight / 263;
        final titleFontSize = 14 * scale;
        final priceFontSize = 16 * scale;
        final locationFontSize = 13 * scale;
        final dateFontSize = 12 * scale;
        final iconSize = 16 * scale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: imageHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Image.asset(
                  widget.listing.imagePath,
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

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.listing.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4 * scale),
                      GestureDetector(
                        onTap: _toggleFavorite,
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : textPrimary,
                          size: iconSize,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 3 * scale),
                  Text(
                    widget.listing.price,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  SizedBox(height: 3 * scale),
                  Text(
                    widget.listing.location,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: locationFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 1 * scale),

                  Text(
                    widget.listing.date,
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
