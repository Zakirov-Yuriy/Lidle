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

  /// Флаг, указывающий является ли это основным каталогом.
  /// Если true - это каталог (Недвижимость, Работа, Подработка и т.д.)
  /// Если false - это подкатегория (Продажа квартир, Аренда и т.д.)
  final bool isCatalog;

  /// Конструктор для создания экземпляра [Category].
  const Category({
    this.id,
    required this.title,
    required this.color,
    required this.imagePath,
    this.isCatalog = true,
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
    this.characteristics =
        const {}, // 🔥 NOTE: This creates immutable map - will be replaced with mutable later if needed
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    // Парсим характеристики из attributes (возвращаемых API, в формате структуры attributes)
    final Map<String, dynamic> characteristics = {};

    // 🔍 DEBUG: Логируем структуру attributes для диагностики
    if (json['attributes'] != null) {
      print(
        '\n🔍 [Listing.fromJson] ID=${json['id']}, attributes type: ${json['attributes'].runtimeType}',
      );
      if (json['attributes'] is Map) {
        final attrs = json['attributes'] as Map;
        print('   attributes keys: ${attrs.keys.toList()}');
        attrs.forEach((k, v) {
          print('   [$k]: ${v.runtimeType} = $v');
        });
      } else {
        print('   attributes is not Map! Value: ${json['attributes']}');
      }
    }

    if (json['attributes'] != null && json['attributes'] is Map) {
      final attrs = json['attributes'];

      // 🟢 ВАЖНО: Парсим ОБА value_selected (ID < 1000) И values (ID >= 1000)
      // Оба вида атрибутов нужны для корректной фильтрации на клиенте

      // Парсим value_selected атрибуты (ID < 1000)
      if (attrs['value_selected'] != null && attrs['value_selected'] is Map) {
        final valueSelected = attrs['value_selected'] as Map;
        valueSelected.forEach((key, valueObj) {
          // key должен быть строкой (атрибут ID)
          // valueObj может быть Map или простой объект с 'value' и другими полями
          characteristics[key.toString()] = _parseAttributeValue(valueObj);
        });
      }

      // Парсим values атрибуты (ID >= 1000)
      if (attrs['values'] != null && attrs['values'] is Map) {
        final values = attrs['values'] as Map;
        values.forEach((key, valueObj) {
          // key должен быть строкой (атрибут ID)
          // valueObj может быть Map с min/max или простое значение
          characteristics[key.toString()] = _parseAttributeValue(valueObj);
        });
      }
    }

    // DEBUG: Показываем финальную структуру characteristics
    if (characteristics.isNotEmpty) {
      print('   Final characteristics: ${characteristics.keys.toList()}');
      characteristics.forEach((k, v) {
        print('      [$k]: ${v.runtimeType} = $v');
      });
    } else {
      print('   Final characteristics: EMPTY');
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

  /// Helper метод для парсинга значений атрибутов
  /// Обрабатывает разные форматы: Map, простые значения, List
  /// Возвращает нормализованное значение для фильтрации
  static dynamic _parseAttributeValue(dynamic valueObj) {
    if (valueObj == null) {
      return null;
    }

    // Если это Map - это может быть структура с 'value', 'min', 'max' и т.д.
    if (valueObj is Map) {
      // Для value_selected атрибутов (ID < 1000)
      // Формат: {id: 18, title: "...", value: 154, max_value: null}
      if (valueObj.containsKey('value')) {
        return valueObj['value'];
      }
      // Для values атрибутов (ID >= 1000) - диапазоны
      // Формат: {min: 500000, max: 1200000}
      if (valueObj.containsKey('min') || valueObj.containsKey('max')) {
        return {'min': valueObj['min'], 'max': valueObj['max']};
      }
      // В иных случаях просто возвращаем Map
      return valueObj;
    }

    // Если это List - возвращаем как есть
    if (valueObj is List) {
      return valueObj;
    }

    // Если это простое значение (String, int, double, bool) - возвращаем как есть
    return valueObj;
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
