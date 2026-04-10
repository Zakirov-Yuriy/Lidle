import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/features/cart/presentation/pages/cart_screen.dart';
import 'package:lidle/features/cart/domain/entities/cart_item_entity.dart';
import 'package:lidle/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:lidle/blocs/wishlist/wishlist_bloc.dart';
import 'package:lidle/core/logger.dart';

class ProductCard extends StatefulWidget {
  final Listing listing;

  const ProductCard({
    super.key,
    required this.listing,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = HiveService.getFavorites().contains(widget.listing.id);
  }

  void _toggleFavorite() {
    // Проверяем текущее состояние в Hive перед изменением
    final currentFavorite = HiveService.isFavorite(widget.listing.id);
    
    setState(() {
      _isFavorite = !currentFavorite;
    });
    
    // Обновляем локальное хранилище (Hive)
    if (_isFavorite != currentFavorite) {
      HiveService.toggleFavorite(widget.listing.id);
      
      // 🔄 Отправляем запрос на сервер через WishlistBloc
      // Преобразуем ID объявления из String в int
      final advertId = int.tryParse(widget.listing.id);
      if (advertId != null) {
        if (_isFavorite) {
          // Добавляем в wishlist на сервере
          // log.i('💗 ProductCard: Отправляем AddToWishlistEvent для advert_id=$advertId');
          context.read<WishlistBloc>().add(
            AddToWishlistEvent(listingId: advertId),
          );
        } else {
          // Удаляем из wishlist на сервере
          // log.i('💔 ProductCard: Отправляем RemoveFromWishlistEvent для advert_id=$advertId');
          context.read<WishlistBloc>().add(
            RemoveFromWishlistEvent(listingId: advertId),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                child: Image.asset(
                  widget.listing.imagePath,
                  height: 164,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleFavorite,
                  child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : textPrimary,
                    size: 25,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.listing.title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.listing.price}₽',
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.listing.location,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.listing.date,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Создаем CartItem из Listing
                      final cartItem = CartItem.fromListing(
                        widget.listing,
                        oldPrice: '25000', // Для демонстрации, можно передавать динамически
                      );

                      // Добавляем в корзину через Bloc
                      context.read<CartBloc>().add(AddToCartEvent(cartItem));

                      // Переходим к экрану корзины
                      Navigator.pushNamed(context, CartScreen.routeName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeIconColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(double.infinity, 35),
                    ),
                    child: const Text(
                      'В корзину',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
