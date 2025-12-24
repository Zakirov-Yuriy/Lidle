import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/pages/offers/price_accepted_page.dart';
import 'package:lidle/pages/offers/price_offers_list_page.dart';

class OfferCard extends StatelessWidget {
  final Offer offer;

  const OfferCard({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final bool isOfferToMe = offer.offeredPricesCount != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      padding: const EdgeInsets.only(top: 16, left: 10, right: 10, bottom: 14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          // ───── Image and details ─────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  offer.imageUrl,
                  width: 105,
                  height: 74,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '№ ${offer.id}',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (!isOfferToMe)
                          Text(
                            offer.viewed ? 'Просмотрено' : 'Не просмотрено',
                            style: TextStyle(
                              color: offer.viewed ? textMuted : textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.originalPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF474747), height: 12),

          // ───── Middle section (Offered prices or Your price) ─────
          if (isOfferToMe)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFFE8FF00),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Предложенных цен: ${offer.offeredPricesCount}',
                    style: const TextStyle(
                      color: Color(0xFFE8FF00),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ваша цена: ${offer.yourPrice}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildStatusWidget(offer.status),
              ],
            ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFF474747), height: 9),
          // ───── View button ─────
          GestureDetector(
            onTap: () {
              if (isOfferToMe) {
                Navigator.pushNamed(context, PriceOffersListPage.routeName,
                    arguments: offer);
              } else {
                Navigator.pushNamed(context, PriceAcceptedPage.routeName,
                    arguments: offer);
              }
            },
            child: Text(
              'Просмотреть',
              style: TextStyle(
                color: activeIconColor,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  Widget _buildStatusWidget(OfferStatus status) {
    switch (status) {
      case OfferStatus.accepted:
        return const Text(
          'Цена принята',
          style: TextStyle(
            color: Color(0xFF00B7FF),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        );
      case OfferStatus.rejected:
        return const Text(
          'Отказ от цены',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        );
      case OfferStatus.pending:
        return const SizedBox.shrink(); // No status displayed for pending
    }
  }
}
