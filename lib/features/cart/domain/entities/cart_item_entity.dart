// ============================================================
//  Cart Item Entity
// ============================================================

import 'package:lidle/models/home_models.dart';

class CartItem {
  final String id;
  final String imagePath;
  final String title;
  final String price;
  final String oldPrice; // Добавлено для старой цены
  final String color; // Добавлено поле цвета
  int quantity;
  bool isSelected; // Добавлено поле для индивидуального выбора

  CartItem({
    required this.id,
    required this.imagePath,
    required this.title,
    required this.price,
    required this.oldPrice,
    this.color = 'Серый', // По умолчанию серый цвет
    this.quantity = 1,
    this.isSelected = false, // По умолчанию не выбран
  });

  // Создание CartItem из Listing
  factory CartItem.fromListing(Listing listing, {String? oldPrice}) {
    return CartItem(
      id: listing.id,
      imagePath: listing.imagePath,
      title: listing.title,
      price: listing.price,
      oldPrice: oldPrice ?? listing.price, // Если старая цена не указана, используем текущую
    );
  }

  CartItem copyWith({
    String? id,
    String? imagePath,
    String? title,
    String? price,
    String? oldPrice,
    String? color,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      title: title ?? this.title,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
    );
  }
}
