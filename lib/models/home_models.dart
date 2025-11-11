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

/// Модель данных для объявления (листинга).
/// Используется для отображения отдельных объявлений на главной странице.
class Listing {
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

  /// Конструктор для создания экземпляра [Listing].
  const Listing({
    required this.imagePath,
    required this.title,
    required this.price,
    required this.location,
    required this.date,
  });
}
