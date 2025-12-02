/// Файл, содержащий модели данных для главной страницы приложения.
/// Включает определения классов `Category` и `Listing`.
import 'package:flutter/material.dart';

/// Модель данных для категории.
/// Используется для отображения различных категорий предложений на главной странице.
class Category {
  /// Заголовок категории, например, "Автомобили" или "Недвижимость".
  final String title;
  /// Цвет, связанный с категорией, для визуального оформления.
  final Color color;
  /// Путь к изображению, представляющему категорию.
  final String imagePath;

  /// Конструктор для создания экземпляра [Category].
  const Category({
    required this.title,
    required this.color,
    required this.imagePath,
  });
}

/// Перечисление для опций сортировки объявлений.
enum SortOption {
  newest,
  oldest,
  mostExpensive,
  cheapest,
}

/// Модель данных для объявления (листинга).
/// Используется для отображения отдельных объявлений на главной странице.
class Listing {
  /// Уникальный идентификатор объявления.
  final String id;
  /// Путь к изображению, представляющему объявление.
  final String imagePath;
  /// Заголовок объявления.
  final String title;
  /// Цена, указанная в объявлении.
  final String price;
  /// Местоположение объекта объявления.
  final String location;
  /// Дата публикации или обновления объявления.
  final String date;
  /// Флаг, указывающий, добавлено ли объявление в избранное.
  bool isFavorited; // Added isFavorited field

  /// Конструктор для создания экземпляра [Listing].
  Listing({ // Changed to non-const constructor
    required this.id,
    required this.imagePath,
    required this.title,
    required this.price,
    required this.location,
    required this.date,
    this.isFavorited = false, // Default to false
  });
}
