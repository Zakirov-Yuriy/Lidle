// ============================================================
//  "Карточка объявления"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lidle/blocs/wishlist/wishlist_bloc.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/pages/products/product_details_screen.dart';

// ============================================================
// "Утилиты для форматирования"
// ============================================================
/// Форматирует цену: "1000000,00" → "1 000 000 ₽"
String _formatPriceWithRuble(String price) {
  if (price.isEmpty) return '₽';
  
  // Удаляем копейки (всё после запятой)
  final integerPart = price.contains(',') 
      ? price.split(',')[0] 
      : price.split('.')[0];
  
  // Добавляем пробелы между разрядами
  final parts = <String>[];
  for (var i = integerPart.length; i > 0; i -= 3) {
    final start = (i - 3) < 0 ? 0 : (i - 3);
    parts.insert(0, integerPart.substring(start, i));
  }
  
  final formatted = parts.join(' ');
  return '$formatted ₽';
}

// ============================================================

class ListingCard extends StatefulWidget {
  final Listing listing;
  final VoidCallback? onBeforeNavigate;

  /// Считать показ карточки как «Просмотр» (импрессия). Включать ТОЛЬКО в
  /// лентах-выдачах: главная, лента категории, результаты фильтра и строки
  /// поиска. Не включать в избранном, «Мои объявления» и профиле продавца —
  /// там показ карточки не является просмотром из поиска.
  final bool countImpression;

  const ListingCard({
    super.key,
    required this.listing,
    this.onBeforeNavigate,
    this.countImpression = false,
  });

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  late bool _isFavorite;

  /// Кнопка «В корзину» нажата и ответ ещё не пришёл.
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = HiveService.getFavorites().contains(widget.listing.id);

    // Товар в ленте главной (09.09.2026) — не объявление: ни просмотров, ни
    // избранного у него здесь нет. Счётчик просмотров объявлений принял бы
    // номер товара за номер объявления и накрутил чужую статистику.
    if (widget.listing.isProduct) {
      return;
    }

    // «Просмотр» = показ карточки в выдаче. Шлём один раз за сессию на
    // объявление (гуард внутри saveAdvertViewOnce); дневной дедуп — на бэке.
    if (widget.countImpression) {
      final id = int.tryParse(widget.listing.id);
      if (id != null) {
        ApiService.saveAdvertViewOnce(id);
      }
    }
  }

  void _toggleFavorite() {
    // Проверяем текущее состояние перед изменением
    final currentFavorite = HiveService.isFavorite(widget.listing.id);
    final newState = !currentFavorite;
    
    // Только обновляем UI локально для оптимистичного отображения
    setState(() {
      _isFavorite = newState;
    });
    
    // 🔄 Отправляем событие в WishlistBloc для обработки API запроса
    // WishlistBloc сам обновит Hive ПОСЛЕ успешного ответа с сервера
    final advertId = int.tryParse(widget.listing.id);
    if (advertId != null) {
      if (newState) {
        // Добавляем в wishlist на сервере
        // log.i('💗 ListingCard: Отправляем AddToWishlistEvent для advert_id=$advertId');
        context.read<WishlistBloc>().add(
          AddToWishlistEvent(listingId: advertId),
        );
      } else {
        // Удаляем из wishlist на сервере
        // log.i('💔 ListingCard: Отправляем RemoveFromWishlistEvent для advert_id=$advertId');
        context.read<WishlistBloc>().add(
          RemoveFromWishlistEvent(
            listingId: advertId,
            wishlistId: widget.listing.wishlistId,
          ),
        );
      }
    }
  }

  /// Положить товар в корзину прямо из ленты.
  Future<void> _addToCart() async {
    final productId = widget.listing.productId;

    if (productId == null || _isAdding) return;

    setState(() => _isAdding = true);

    final result = await CartService.add(productId);

    if (!mounted) return;

    setState(() => _isAdding = false);

    if (!result.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Не получилось добавить в корзину'),
          backgroundColor: secondaryBackground,
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Товар в корзине'),
        backgroundColor: secondaryBackground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Карточка ТОВАРА. Отдельной веткой, а не флажками внутри общей вёрстки:
    // у товара нет адреса, даты и сердечка, зато есть кнопка «В корзину», и
    // сшивать это в один макет значит получить карточку из одних условий.
    if (widget.listing.isProduct) {
      return _buildProductCard(context);
    }

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

        return GestureDetector(
          onTap: () {
            // 💾 Вызываем callback для сохранения позиции скролла
            widget.onBeforeNavigate?.call();
            
            // 🔓 Переходим к деталям объявления (доступно для всех, включая неавторизованных)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MiniPropertyDetailsScreen(listing: widget.listing),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: imageHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5 * scale),
                  child: widget.listing.imagePath.isEmpty
                      ? Container(
                          color: const Color(0xFF374B5C),
                          child: Icon(
                            Icons.image_not_supported,
                            color: textMuted,
                            size: 50 * scale,
                          ),
                        )
                      : widget.listing.imagePath.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: widget.listing.imagePath,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: const Color(0xFF374B5C)),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF374B5C),
                            child: Icon(
                              Icons.image,
                              color: textMuted,
                              size: 50 * scale,
                            ),
                          ),
                        )
                      : Image.asset(
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

              SizedBox(height: 18),

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
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : textPrimary,
                          ),
                        ),
                      ],
                    ),

                    Text(
                      _formatPriceWithRuble(widget.listing.price),
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
          ),
        );
      },
    );
  }

  /// Карточка товара: картинка, цена, название, магазин и «В корзину».
  ///
  /// Кнопки нет, когда у раздела не заведён атрибут оплаты (`can_order`):
  /// такой товар покупают на месте, и корзина для него не работает. Рисовать
  /// кнопку, которая ответит отказом, значит водить человека по кругу.
  Widget _buildProductCard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;

        final imageHeight = cardHeight * (cardWidth < 140 ? 0.46 : 0.52);
        final scale = cardHeight / 263;

        return GestureDetector(
          onTap: () {
            widget.onBeforeNavigate?.call();

            final productId = widget.listing.productId;

            if (productId == null) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(productId: productId),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: widget.listing.imagePath.isEmpty
                      ? Container(
                          color: formBackground,
                          child: const Icon(
                            Icons.photo_outlined,
                            color: textMuted,
                            size: 28,
                          ),
                        )
                      : Image.network(
                          widget.listing.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: formBackground,
                            child: const Icon(
                              Icons.photo_outlined,
                              color: textMuted,
                              size: 28,
                            ),
                          ),
                        ),
                ),
              ),

              SizedBox(height: 6 * scale),

              Text(
                '${widget.listing.price} ₽',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(height: 2 * scale),

              Text(
                widget.listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textPrimary, fontSize: 14 * scale),
              ),

              if (widget.listing.location.isNotEmpty) ...[
                SizedBox(height: 2 * scale),
                Text(
                  widget.listing.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textMuted, fontSize: 12 * scale),
                ),
              ],

              const Spacer(),

              if (widget.listing.canOrder)
                SizedBox(
                  width: double.infinity,
                  height: 34 * scale,
                  child: OutlinedButton(
                    onPressed: _isAdding ? null : _addToCart,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: activeIconColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      _isAdding ? 'Добавляем…' : 'В корзину',
                      style: TextStyle(
                        color: activeIconColor,
                        fontSize: 13 * scale,
                      ),
                    ),
                  ),
                )
              else
                // Товар без корзины: говорим об этом прямо, иначе человек
                // ищет кнопку и думает, что приложение сломалось.
                Text(
                  'Покупка на месте',
                  style: TextStyle(color: textMuted, fontSize: 12 * scale),
                ),
            ],
          ),
        );
      },
    );
  }
}
