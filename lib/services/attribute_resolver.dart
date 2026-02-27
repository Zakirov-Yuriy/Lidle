// ============================================================
// "Сервис для динамического разрешения ID атрибутов"
// ============================================================
//
// Этот сервис решает проблему hardcoded ID атрибутов, позволяя
// динамически находить ID нужных атрибутов для любой категории
// на основе названия или типа атрибута.
//
// Вместо того чтобы поддерживать большие switch statements с ID,
// мы ищем атрибут в загруженном списке по названию/признакам.
//
// Примеры использования:
//   - attributeId = resolver.findAttributeIdByName('Вам предложат цену');
//   - attributeId = resolver.findAttributeIdByName('Общая площадь');
//   - attributeId = resolver.findAttributeIdByName('Количество комнат');
//   - attributeId = resolver.findAttributeIdByName('Частное лицо|Бизнес');

import 'package:lidle/models/filter_models.dart';

class AttributeResolver {
  final List<Attribute> attributes;

  /// Создает resolver для списка атрибутов
  /// Обычно это список, загруженный из API для конкретной категории
  AttributeResolver(this.attributes);

  /// Поиск атрибута по точному названию
  /// Примеры: 'Вам предложат цену', 'Общая площадь', 'Количество комнат'
  int? findAttributeIdByName(String name) {
    try {
      final attr = attributes.firstWhere(
        (a) => a.title.toLowerCase().trim() == name.toLowerCase().trim(),
      );
      return attr.id;
    } catch (_) {
      return null;
    }
  }

  /// Поиск атрибута по содержанию названия (case-insensitive)
  /// Примеры:
  ///   - findAttributeIdByPartialName('площадь') найдёт 'Общая площадь'
  ///   - findAttributeIdByPartialName('комнат') найдёт 'Количество комнат'
  ///   - findAttributeIdByPartialName('цену') найдёт 'Вам предложат цену'
  int? findAttributeIdByPartialName(String partialName) {
    try {
      final lowerPartial = partialName.toLowerCase().trim();
      final attr = attributes.firstWhere(
        (a) => a.title.toLowerCase().contains(lowerPartial),
      );
      return attr.id;
    } catch (_) {
      return null;
    }
  }

  /// Поиск по регулярному выражению (для сложных случаев)
  /// Пример: findAttributeIdByRegex(RegExp(r'(продажа|аренда|цена)'))
  int? findAttributeIdByRegex(RegExp regex) {
    try {
      final attr = attributes.firstWhere(
        (a) => regex.hasMatch(a.title.toLowerCase()),
      );
      return attr.id;
    } catch (_) {
      return null;
    }
  }

  /// Поиск по типу данных (boolean, string, integer, numeric)
  /// и требуемости
  /// Полезно для поиска обязательных булевых полей
  int? findAttributeIdByDataType({
    String? dataType,
    bool? isRequired,
    bool? isRange,
    bool? isMultiple,
    bool? isHidden,
  }) {
    try {
      final attr = attributes.firstWhere((a) {
        if (dataType != null && a.dataType != dataType) return false;
        if (isRequired != null && a.isRequired != isRequired) return false;
        if (isRange != null && a.isRange != isRange) return false;
        if (isMultiple != null && a.isMultiple != isMultiple) return false;
        if (isHidden != null && a.isHidden != isHidden) return false;
        return true;
      });
      return attr.id;
    } catch (_) {
      return null;
    }
  }

  /// Получить атрибут по ID
  Attribute? getAttributeById(int id) {
    try {
      return attributes.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Получить все обязательные атрибуты
  List<Attribute> getRequiredAttributes() {
    return attributes.where((a) => a.isRequired).toList();
  }

  /// Получить все скрытые атрибуты (is_hidden=true)
  List<Attribute> getHiddenAttributes() {
    return attributes.where((a) => a.isHidden).toList();
  }

  /// Получить все атрибуты с диапазоном значений
  List<Attribute> getRangeAttributes() {
    return attributes.where((a) => a.isRange).toList();
  }

  /// Получить все атрибуты с множественным выбором
  List<Attribute> getMultipleSelectionAttributes() {
    return attributes.where((a) => a.isMultiple).toList();
  }

  /// Получить атрибут "Вам предложат цену"
  /// Это критический атрибут, который должен быть в каждой категории
  /// но с разными ID (1048, 1050, 1051, 1052, 1128, 1130 и т.д.)
  int? getOfferPriceAttributeId() {
    // Ищем по названию
    var id = findAttributeIdByName('Вам предложат цену');
    if (id != null) return id;

    // Если не нашли по названию, ищем булевый обязательный атрибут
    id = findAttributeIdByDataType(dataType: 'boolean', isRequired: true);
    return id;
  }

  /// Получить атрибут "Общая площадь" или "Площадь"
  /// Для недвижимости обычно это диапазон целых / decimal значений
  int? getAreaAttributeId() {
    // Ищем по названию
    var id = findAttributeIdByPartialName('площадь');
    if (id != null) return id;

    // Если не нашли, ищем обязательный диапазон целых чисел
    id = findAttributeIdByDataType(
      isRequired: true,
      isRange: true,
      dataType: 'integer',
    );
    return id;
  }

  /// Получить атрибут "Количество комнат"
  /// Обычно это множественный выбор с предопределенными значениями
  int? getRoomsAttributeId() {
    // Ищем по названию
    var id = findAttributeIdByPartialName('комнат');
    if (id != null) return id;

    // Если не нашли, ищем множественный выбор с определенными значениями
    id = findAttributeIdByDataType(isMultiple: true);
    return id;
  }

  /// Получить атрибут для типа продавца "Частное лицо / Бизнес"
  /// Обычно это множественный выбор
  int? getSellerTypeAttributeId() {
    // Ищем по названию
    var id = findAttributeIdByPartialName('лиц');
    if (id != null) return id;

    id = findAttributeIdByPartialName('бизнес');
    if (id != null) return id;

    // Если не нашли, ищем множественный выбор с определенными значениями
    id = findAttributeIdByDataType(isMultiple: true);
    return id;
  }

  /// Получить атрибут "Этаж"
  /// Может быть диапазоном или простым полем
  int? getFloorAttributeId() {
    // Ищем по названию
    return findAttributeIdByPartialName('этаж');
  }

  /// Получить атрибут "Возможен торг" / "Торговаться"
  int? getBargainAttributeId() {
    // Ищем по названию
    var id = findAttributeIdByPartialName('торг');
    if (id != null) return id;

    // Если не нашли, ищем скрытый множественный булевый атрибут
    id = findAttributeIdByDataType(
      dataType: 'boolean',
      isHidden: true,
      isMultiple: true,
    );
    return id;
  }

  /// Отладочный вывод: логирует все атрибуты с их свойствами
  void debugPrintAll({String prefix = ''}) {
    final padLength = attributes
        .map((a) => a.id.toString().length)
        .fold<int>(0, (max, len) => len > max ? len : max);

    // print('$prefix═══════════════════════════════════════════════════');
    // print('$prefix📋 ATTRIBUTE RESOLVER: ${attributes.length} attributes');
    // print('$prefix═══════════════════════════════════════════════════');

    for (final attr in attributes) {
      final idStr = attr.id.toString().padRight(padLength);
      final flags = [
        if (attr.isRequired) '✓required',
        if (attr.isHidden) '✓hidden',
        if (attr.isRange) '✓range',
        if (attr.isMultiple) '✓multiple',
        if (attr.isTitleHidden) '✓titleHidden',
      ].join(', ');

      final flagsStr = flags.isNotEmpty ? ' [$flags]' : '';
      final dataTypeStr = attr.dataType != null && attr.dataType!.isNotEmpty
          ? ' (${attr.dataType})'
          : '';
      final valuesCount = attr.values.isNotEmpty
          ? ' - ${attr.values.length} values'
          : '';

      // print('$prefix[$idStr] ${attr.title}$dataTypeStr$flagsStr$valuesCount');

      // Логируем значения для атрибутов с предопределенными значениями
      if (attr.values.isNotEmpty && attr.values.length <= 10) {
        for (final val in attr.values) {
          // print('$prefix    • ${val.value} (id=${val.id})');
        }
      }
    }

    // print('$prefix═══════════════════════════════════════════════════');
  }

  /// Вывести отчет о найденных критических атрибутах
  void debugPrintCriticalAttributes({String prefix = ''}) {
    // print('$prefix🔍 CRITICAL ATTRIBUTES:');

    final offerPrice = getOfferPriceAttributeId();
    // print(
    //   '$prefix   Offer Price: ${offerPrice != null ? '✓ ID=$offerPrice' : '✗ NOT FOUND'}',
    // );

    final area = getAreaAttributeId();
    // print('$prefix   Area: ${area != null ? '✓ ID=$area' : '✗ NOT FOUND'}');

    final rooms = getRoomsAttributeId();
    // print('$prefix   Rooms: ${rooms != null ? '✓ ID=$rooms' : '✗ NOT FOUND'}');

    final sellerType = getSellerTypeAttributeId();
    // print(
    //   '$prefix   Seller Type: ${sellerType != null ? '✓ ID=$sellerType' : '✗ NOT FOUND'}',
    // );

    final floor = getFloorAttributeId();
    // print('$prefix   Floor: ${floor != null ? '✓ ID=$floor' : '✗ NOT FOUND'}');

    final bargain = getBargainAttributeId();
    // print(
    //   '$prefix   Bargain: ${bargain != null ? '✓ ID=$bargain' : '✗ NOT FOUND'}',
    // );
  }
}
