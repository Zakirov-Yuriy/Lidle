/// Файл, содержащий модели данных для главной страницы приложения.
/// Включает определения классов `Category` и `Listing`.
import 'package:flutter/material.dart';

/// Модель данных для категории.
/// Используется для отображения различных категорий предложений на главной странице.
class Category {
  /// Уникальный идентификатор категории из API.
  final int? id;

  /// Заголовок категории, например, "Автомобили" или "Недвижимость".
  final String title;

  /// Цвет, связанный с категорией, для визуального оформления.
  final Color color;

  /// Путь к изображению, представляющему категорию.
  final String imagePath;

  /// Конструктор для создания экземпляра [Category].
  const Category({
    this.id,
    required this.title,
    required this.color,
    required this.imagePath,
  });
}

/// Перечисление для опций сортировки объявлений.
enum SortOption { newest, oldest, mostExpensive, cheapest }

/// Модель данных для объявления (листинга).
/// Используется для отображения отдельных объявлений на главной странице.
class Listing {
  /// Уникальный идентификатор объявления.
  final String id;

  /// Путь к изображению, представляющему объявление.
  final String imagePath;

  /// Список всех изображений объявления.
  final List<String> images;

  /// Заголовок объявления.
  final String title;

  /// Цена, указанная в объявлении.
  final String price;

  /// Местоположение объекта объявления.
  final String location;

  /// Дата публикации или обновления объявления.
  final String date;

  /// Характеристики недвижимости (например, количество комнат, площадь и т.д.)
  final Map<String, dynamic> characteristics;

  /// Имя продавца
  final String? sellerName;

  /// ID продавца/пользователя
  final String? userId;

  /// Аватарка продавца (URL или путь к активу)
  final String? sellerAvatar;

  /// Дата регистрации продавца на платформе
  final String? sellerRegistrationDate;

  /// Описание объявления (может быть null)
  final String? description;

  /// Флаг, указывающий, добавлено ли объявление в избранное.
  final bool isFavorited;

  /// Конструктор для создания экземпляра [Listing].
  Listing({
    // Changed to non-const constructor
    required this.id,
    required this.imagePath,
    this.images = const [],
    required this.title,
    required this.price,
    required this.location,
    required this.date,
    this.isFavorited = false,
    this.sellerName,
    this.userId,
    this.sellerAvatar,
    this.sellerRegistrationDate,
    this.description,
    this.characteristics = const {},
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    // Парсим характеристики из attributes (values)
    final Map<String, dynamic> characteristics = {};
    print('[DEBUG] Listing.fromJson attributes:');
    print(json['attributes']);
    if (json['attributes'] != null && json['attributes'] is Map) {
      final attrs = json['attributes'];
      if (attrs['values'] != null && attrs['values'] is Map) {
        final values = attrs['values'] as Map;
        values.forEach((key, valueObj) {
          characteristics[key.toString()] = valueObj;
        });
      }
    }

    return Listing(
      id:
          json['id'] ??
          UniqueKey()
              .toString(), // Assuming 'id' might be missing, generate a unique one
      imagePath:
          json['image'] ??
          'assets/home_page/image.png', // Default image if not provided
      images: List<String>.from(json['images'] ?? []),
      title: json['title'] ?? 'No Title',
      price: json['price'] ?? '0',
      location:
          json['address'] ??
          'Unknown Location', // Assuming 'address' corresponds to 'location'
      date: json['date'] ?? 'Unknown Date',
      isFavorited: json['isFavorited'] ?? false,
      sellerName: json['seller']?['name'] ?? json['sellerName'],
      userId: json['seller']?['id']?.toString() ?? json['userId'],
      sellerAvatar: json['seller']?['avatar'] ?? json['sellerAvatar'],
      sellerRegistrationDate:
          json['seller']?['registrationDate'] ?? json['sellerRegistrationDate'],
      description: json['description'],
      characteristics: characteristics,
    );
  }

  /// Конвертирует Listing объект в JSON Map для передачи между экранами
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': imagePath,
      'images': images,
      'title': title,
      'price': price,
      'address': location,
      'date': date,
      'isFavorited': isFavorited,
      'description': description,
      'seller': {
        'id': userId,
        'name': sellerName,
        'avatar': sellerAvatar,
        'registrationDate': sellerRegistrationDate,
      },
      'attributes': {'values': characteristics},
    };
  }
}
