enum OfferStatus { accepted, rejected, pending }

class Offer {
  final String id; // ID предложения (offer ID)
  final String? advertisementId; // ID объявления (advert/product ID)
  final String? slug; // Slug объявления (например: "6-2-49-5-")
  final String? typeSlug; // Type slug для API запросов (например: "adverts")
  final String imageUrl;
  final String title;
  final String description;
  final String originalPrice;
  final String yourPrice;
  final OfferStatus status;
  final bool viewed;
  final int? offeredPricesCount; // Added for "Offers to me" card
  /// true если все офферы к этому объявлению приняты (statusId == 2).
  /// При нажатии "Просмотреть" сразу переходим на /user-account, минуя PriceOffersListPage.
  final bool allOffersAccepted;

  Offer({
    required this.id,
    this.advertisementId,
    this.slug,
    this.typeSlug,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.originalPrice,
    required this.yourPrice,
    required this.status,
    this.viewed = false,
    this.offeredPricesCount,
    this.allOffersAccepted = false,
  });

  /// Создаёт копию объекта с изменёнными полями
  Offer copyWith({
    String? id,
    String? advertisementId,
    String? slug,
    String? typeSlug,
    String? imageUrl,
    String? title,
    String? description,
    String? originalPrice,
    String? yourPrice,
    OfferStatus? status,
    bool? viewed,
    int? offeredPricesCount,
    bool? allOffersAccepted,
  }) {
    return Offer(
      id: id ?? this.id,
      advertisementId: advertisementId ?? this.advertisementId,
      slug: slug ?? this.slug,
      typeSlug: typeSlug ?? this.typeSlug,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      originalPrice: originalPrice ?? this.originalPrice,
      yourPrice: yourPrice ?? this.yourPrice,
      status: status ?? this.status,
      viewed: viewed ?? this.viewed,
      offeredPricesCount: offeredPricesCount ?? this.offeredPricesCount,
      allOffersAccepted: allOffersAccepted ?? this.allOffersAccepted,
    );
  }
}

class PriceOfferItem {
  final String name;
  final String subtitle;
  final String price;
  final String badgeCount;
  final String avatar;

  // ID самого предложения (offer['id']) — нужен для PUT /me/offers/received/{id}
  final String? offerId;

  // Данные объявления на которое сделано предложение (из model в API)
  final String? listingId; // ID объявления
  final String? listingTitle; // Название объявления
  final String? listingPrice; // Цена объявления
  final String? listingImage; // URL фото объявления
  final String? message; // Сообщение от покупателя

  /// true если предложение уже принято (statusId == 2).
  /// При нажатии на такой элемент в списке переходим на аккаунт покупателя,
  /// а не на экран «Принять / Отклонить».
  final bool isAccepted;

  /// true если предложение отклонено (statusId == 3).
  /// Используется для отображения красного badge в списке.
  final bool isRejected;

  PriceOfferItem({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.badgeCount,
    required this.avatar,
    this.offerId,
    this.listingId,
    this.listingTitle,
    this.listingPrice,
    this.listingImage,
    this.message,
    this.isAccepted = false,
    this.isRejected = false,
  });
}
