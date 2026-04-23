/// Файл, содержащий модели данных для главной страницы приложения.
/// Включает определения классов `Category` и `Listing`.
import 'package:flutter/material.dart';
import 'package:lidle/core/logger.dart';

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

  /// Slug объявления для API запросов
  final String? slug;

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

  /// Отдельные компоненты адреса для детального отображения
  final String? region;
  final String? city;
  final String? street;
  final String? buildingNumber;
  
  // Новые поля для хранения адресных компонентов из API
  final String? mainRegion; // Область/регион верхнего уровня
  final String? subRegion;  // Район/область второго уровня
  final String? district;   // Район города

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

  /// Возможен торг (показывать кнопку "Предложить свою цену" или нет)
  final bool isBargain;

  /// Конструктор для создания экземпляра [Listing].
  Listing({
    // Changed to non-const constructor
    required this.id,
    required this.imagePath,
    this.slug,
    this.images = const [],
    required this.title,
    required this.price,
    required this.location,
    required this.date,
    this.isFavorited = false,
    this.isBargain = false,
    this.sellerName,
    this.userId,
    this.sellerAvatar,
    this.sellerRegistrationDate,
    this.description,
    this.characteristics =
        const {}, // 🔥 NOTE: This creates immutable map - will be replaced with mutable later if needed
    this.region,
    this.city,
    this.street,
    this.buildingNumber,
    this.mainRegion,
    this.subRegion,
    this.district,
  });

  /// 🎯 Проверяет, нужно ли показывать кнопку "Предложить свою цену"
  /// Условие: is_bargain == true ИЛИ атрибут "Вам предложат цену" имеет value == 1
  /// Атрибуты для разных категорий:
  /// - 1048 = Продажа квартир
  /// - 1050 = Долгосрочная аренда квартир
  /// - 1051 = Продажа комнат
  /// - 1052 = Долгосрочная аренда комнат
  /// - 1128, 1130 = другие категории
  /// 
  /// Также работает для ЛЮБЫХ других категорий, если там есть атрибут с названием,
  /// содержащим "предложат цену" или "можно торговать"
  bool canShowOfferButton() {
    // 🔍 DEBUG: Логируем вызов метода
    log.d('');
    log.d('🔵 canShowOfferButton() called for listing ID: $id');
    log.d('   - isBargain: $isBargain');
    log.d('   - characteristics.length: ${characteristics.length}');
    log.d('   - characteristics.keys: ${characteristics.keys.toList()}');

    // Проверяем флаг is_bargain
    if (isBargain) {
      log.d('   ✅ RESULT: TRUE (isBargain flag is true)');
      log.d('');
      return true;
    }

    // Все известные ID атрибутов "Вам предложат цену" для разных категорий
    const offerPriceAttrIds = [1048, 1050, 1051, 1052, 1128, 1130];
    
    // Метод 1: Проверяем по известным ID (для недвижимости)
    log.d('   🔍 Метод 1: Проверка по известным ID...');
    for (final attrId in offerPriceAttrIds) {
      final attrIdStr = attrId.toString();
      if (characteristics.containsKey(attrIdStr)) {
        final attrData = characteristics[attrIdStr];
        log.d('      Found attr $attrId: $attrData');
        if (_isOfferPriceValue(attrData)) {
          log.d('   ✅ RESULT: TRUE (found by known ID $attrId)');
          log.d('');
          return true;
        }
      }
    }

    // Метод 2: Универсальный поиск - ищем по названию/title атрибута
    // Работает для любых категорий (Транспорт, Работа, и т.д.)
    log.d('   🔍 Метод 2: Универсальный поиск по названию...');
    for (final entry in characteristics.entries) {
      final attrData = entry.value;
      if (attrData is Map<String, dynamic>) {
        final title = attrData['title'] as String? ?? '';
        log.d('      Attr ${entry.key}: title="$title"');
        // Ищем атрибут с названием, содержащим "предложат цену" или похожие варианты
        if (title.toLowerCase().contains('предложат') || 
            title.toLowerCase().contains('торг') ||
            title.toLowerCase().contains('торговать')) {
          log.d('         → Matched by name!');
          if (_isOfferPriceValue(attrData)) {
            log.d('   ✅ RESULT: TRUE (found by name)');
            log.d('');
            return true;
          }
        }
      }
    }

    log.d('   ❌ RESULT: FALSE (no offer price attribute found)');
    log.d('');
    return false;
  }

  /// Вспомогательный метод: проверяет, что значение атрибута = 1 (истина)
  bool _isOfferPriceValue(dynamic attrData) {
    if (attrData is Map<String, dynamic>) {
      final value = attrData['value'];
      // value может быть int (1), string ("1"), boolean (true)
      final result = value == 1 || value == '1' || value == true;
      log.d('         value: $value (type: ${value.runtimeType}), isOffer: $result');
      return result;
    }
    return false;
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    // DEBUG: Логируем полный JSON адреса
    // log.d('');
    // log.d('═' * 80);
    // log.d('[🔍 PARSING LISTING FROM API]');
    // log.d('Listing ID: ${json['id']}');
    // log.d('Full json address object:');
    // log.d('  json["address"]: ${json['address']}');
    // log.d('  json["location"]: ${json['location']}');
    // log.d('  json["full_address"]: ${json['full_address']}');
    if (json['address'] is Map) {
      // log.d('  address is Map with keys: ${(json['address'] as Map).keys.toList()}');
      // (json['address'] as Map).forEach((k, v) => log.d('    $k: $v'));
    }
    // log.d('═' * 80);
    // log.d('');
    // Парсим характеристики из attributes (возвращаемых API, в формате структуры attributes)
    final Map<String, dynamic> characteristics = {};

    // 🔍 DEBUG: Логируем структуру attributes для диагностики

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
    
    // Получаем строку адреса для парсинга компонентов
    String addressString = '';
    if (json['address'] is String) {
      addressString = json['address'];
    } else if (json['full_address'] is String) {
      addressString = json['full_address'];
    } else if (json['location'] is String) {
      addressString = json['location'];
    }
    
    // Парсим адрес если нет явных компонентов
    final parsedAddress = _parseAddressString(addressString);
    // log.d('[🔍 PARSED ADDRESS FROM STRING]');
    // log.d('  Original: $addressString');
    // log.d('  Parsed city: ${parsedAddress['city']}');
    // log.d('  Parsed street: ${parsedAddress['street']}');
    // log.d('  Parsed buildingNumber: ${parsedAddress['buildingNumber']}');

    return Listing(
      id:
          json['id'] ??
          UniqueKey()
              .toString(), // Assuming 'id' might be missing, generate a unique one
      slug: json['slug'] ?? json['id']?.toString(),
      imagePath:
          json['image'] ??
          'assets/home_page/image.png', // Default image if not provided
      images: List<String>.from(json['images'] ?? []),
      title: json['title'] ?? 'No Title',
      price: json['price'] ?? '0',
      location: _convertAddressToString(json['address']) ??
          json['full_address'] ??
          'Unknown Location', // Assuming 'address' corresponds to 'location'
      region: _extractAddressField(_getAddressFieldValue(json['address'], 'region')) ?? json['region'],
      city: _extractAddressField(_getAddressFieldValue(json['address'], 'city')) ?? json['city'] ?? parsedAddress['city'],
      street: _extractAddressField(_getAddressFieldValue(json['address'], 'street')) ?? json['street'] ?? parsedAddress['street'],
      buildingNumber: _extractAddressField(_getAddressFieldValue(json['address'], 'building_number')) ?? json['building_number'] ?? parsedAddress['buildingNumber'],
      // Извлекаем адресные компоненты из API в соответствии с документацией
      mainRegion: _extractAddressField(_getAddressFieldValue(json['address'], 'main_region')) ?? 
                  _extractAddressField(_getAddressFieldValue(json['address'], 'region_name')) ??
                  json['main_region']?.toString() ??
                  json['region_name']?.toString(),
      subRegion: _extractAddressField(_getAddressFieldValue(json['address'], 'region')) ?? 
                 _extractAddressField(_getAddressFieldValue(json['address'], 'sub_region')) ??
                 json['region']?.toString() ??
                 json['sub_region']?.toString(),
      district: _extractAddressField(_getAddressFieldValue(json['address'], 'district')) ?? 
                _extractAddressField(_getAddressFieldValue(json['address'], 'district_name')) ??
                json['district']?.toString() ??
                json['district_name']?.toString(),
      date: json['date'] ?? 'Unknown Date',
      isFavorited: json['isFavorited'] ?? false,
      isBargain: json['is_bargain'] ?? false,
      // API detail endpoint returns seller info under 'user' key,
      // while some responses may use 'seller' key.
      sellerName:
          json['user']?['name'] ??
          json['seller']?['name'] ??
          json['sellerName'],
      userId:
          json['user']?['id']?.toString() ??
          json['seller']?['id']?.toString() ??
          json['userId'],
      sellerAvatar:
          json['user']?['avatar'] ??
          json['seller']?['avatar'] ??
          json['sellerAvatar'],
      sellerRegistrationDate:
          json['user']?['created_at'] ??
          json['seller']?['registrationDate'] ??
          json['sellerRegistrationDate'],
      description: json['description'],
      characteristics: characteristics,
    );
  }

  /// Helper метод для парсинга значений атрибутов
  /// Обрабатывает разные форматы: Map, простые значения, List
  /// Парсит строку адреса на компоненты (город, улица, номер дома)
  static Map<String, String?> _parseAddressString(String? addressStr) {
    if (addressStr == null || addressStr.isEmpty) {
      return {'city': null, 'street': null, 'buildingNumber': null};
    }

    // Разбиваем на части по запятой
    final parts = addressStr.split(',').map((p) => p.trim()).toList();
    
    String? city, street, buildingNumber;
    
    for (var part in parts) {
      if (part.isEmpty) continue;
      
      // Определяем по префиксу
      if (part.startsWith('г.') || part.startsWith('город')) {
        city = part;
      } else if (part.startsWith('ул.') || part.startsWith('улица') || part.startsWith('пр.') || part.startsWith('проспект')) {
        street = part;
      } else if (part.startsWith('д.') || part.startsWith('дом') || part.startsWith('№')) {
        buildingNumber = part;
      }
    }
    
    return {'city': city, 'street': street, 'buildingNumber': buildingNumber};
  }

  /// Безопасно конвертирует адрес в строку
  /// Обрабатывает случаи когда address может быть String, Map или List
  static String? _convertAddressToString(dynamic address) {
    if (address == null) return null;
    
    // Если это уже строка - возвращаем как есть
    if (address is String) {
      return address;
    }
    
    // Если это Map - пытаемся собрать строку из компонентов
    if (address is Map) {
      final parts = <String>[];
      if (address['main_region'] != null) parts.add(address['main_region'].toString());
      if (address['region'] != null) parts.add(address['region'].toString());
      if (address['city'] != null) parts.add(address['city'].toString());
      if (address['street'] != null) parts.add(address['street'].toString());
      if (address['building_number'] != null) parts.add(address['building_number'].toString());
      
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
      return null;
    }
    
    // Если это List - пытаемся собрать строку из элементов
    if (address is List) {
      final parts = address.map((e) => e?.toString()).whereType<String>().toList();
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
      return null;
    }
    
    // В остальных случаях пытаемся преобразовать в строку
    return address.toString();
  }

  /// Безопасно извлекает значение поля из JSON адреса
  /// Обрабатывает случаи когда address может быть Map или List
  static dynamic _getAddressFieldValue(dynamic address, String fieldName) {
    if (address == null) return null;
    
    // Если address это Map - безопасно получаем значение
    if (address is Map) {
      return address[fieldName];
    }
    
    // Если address это List - возвращаем null (невозможно извлечь по имени)
    if (address is List) {
      return null;
    }
    
    // В остальных случаях возвращаем null
    return null;
  }

  /// Извлекает название адреса из объекта или строки
  static String? _extractAddressField(dynamic field) {
    if (field == null) return null;
    
    if (field is Map) {
      // Если это объект с name - извлекаем name
      if (field.containsKey('name')) {
        return field['name']?.toString();
      }
      // Иначе преобразуем всё в строку
      return field.toString();
    }
    
    // Если это строка - возвращаем как есть
    return field.toString();
  }

  /// Возвращает нормализованное значение для фильтрации
  static dynamic _parseAttributeValue(dynamic valueObj) {
    if (valueObj == null) {
      return null;
    }

    // Если это Map - это может быть структура с 'value', 'min', 'max' и т.д.
    if (valueObj is Map) {
      // ВАЖНО: Сохраняем весь объект атрибута, чтобы сохранить title для поиска
      // Это нужно для проверки атрибутов в canShowOfferButton()
      
      // Для value_selected атрибутов (ID < 1000)
      // Формат: {id: 18, title: "...", value: 154, max_value: null}
      if (valueObj.containsKey('value')) {
        // Возвращаем весь Map, чтобы сохранить title и другую информацию
        return Map<String, dynamic>.from(valueObj);
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
