
enum OfferStatus {
  accepted,
  rejected,
  pending,
}

class Offer {
  final String id;
  final String imageUrl;
  final String title;
  final String description;
  final String originalPrice;
  final String yourPrice;
  final OfferStatus status;
  final bool viewed;
  final int? offeredPricesCount; // Added for "Offers to me" card

  Offer({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.originalPrice,
    required this.yourPrice,
    required this.status,
    this.viewed = false,
    this.offeredPricesCount,
  });
}

class PriceOfferItem {
  final String name;
  final String subtitle;
  final String price;
  final String badgeCount;
  final String avatar;

  PriceOfferItem({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.badgeCount,
    required this.avatar,
  });
}
