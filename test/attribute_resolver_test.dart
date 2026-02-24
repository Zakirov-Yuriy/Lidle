/// Unit тест для AttributeResolver
/// Проверяет что динамический поиск ID атрибутов работает правильно
/// для разных категорий без hardcoding

import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/services/attribute_resolver.dart';

void main() {
  group('AttributeResolver', () {
    /// Создаём мок-данные для тестирования
    /// Используем реальную структуру атрибутов для разных категорий

    // ============================================================
    // Категория 2: Продажа квартир
    // ============================================================
    late List<Attribute> category2Attributes;

    setUp(() {
      // Симулируем атрибуты из API для категории 2 (Продажа квартир)
      category2Attributes = [
        const Attribute(
          id: 6,
          title: 'Количество комнат',
          isMultiple: true,
          isRequired: true,
          order: 1,
          values: [
            Value(id: 40, value: '1 комната'),
            Value(id: 41, value: '2 комнаты'),
            Value(id: 42, value: '3 комнаты'),
          ],
        ),
        const Attribute(
          id: 19,
          title: 'Частное лицо / Бизнес',
          isMultiple: true,
          order: 2,
          values: [
            Value(id: 174, value: 'Частное лицо'),
            Value(id: 175, value: 'Яндекс Недвижимость'),
          ],
        ),
        const Attribute(
          id: 1048,
          title: 'Вам предложат цену',
          dataType: 'boolean',
          isRequired: true,
          isHidden: true,
          isTitleHidden: true,
          order: 999,
          values: [],
        ),
        const Attribute(
          id: 1127,
          title: 'Общая площадь',
          isRange: true,
          isRequired: true,
          dataType: 'integer',
          order: 3,
          values: [],
        ),
      ];
    });

    test('findAttributeIdByName находит атрибут по точному названию', () {
      final resolver = AttributeResolver(category2Attributes);

      expect(resolver.findAttributeIdByName('Количество комнат'), equals(6));
      expect(
        resolver.findAttributeIdByName('Вам предложат цену'),
        equals(1048),
      );
      expect(resolver.findAttributeIdByName('Несуществующий атрибут'), isNull);
    });

    test(
      'findAttributeIdByPartialName находит атрибут по частичному совпадению',
      () {
        final resolver = AttributeResolver(category2Attributes);

        expect(resolver.findAttributeIdByPartialName('комнат'), equals(6));
        expect(resolver.findAttributeIdByPartialName('площадь'), equals(1127));
        expect(resolver.findAttributeIdByPartialName('цену'), equals(1048));
        expect(resolver.findAttributeIdByPartialName('XYZ'), isNull);
      },
    );

    test('findAttributeIdByDataType находит атрибут по типу данных', () {
      final resolver = AttributeResolver(category2Attributes);

      // Булевый обязательный атрибут
      expect(
        resolver.findAttributeIdByDataType(
          dataType: 'boolean',
          isRequired: true,
        ),
        equals(1048),
      );

      // Диапазон целых чисел
      expect(
        resolver.findAttributeIdByDataType(isRange: true, dataType: 'integer'),
        equals(1127),
      );

      // Множественный выбор
      expect(resolver.findAttributeIdByDataType(isMultiple: true), isNotNull);
    });

    test(
      'getOfferPriceAttributeId() корректно находит обязательный атрибут',
      () {
        final resolver = AttributeResolver(category2Attributes);
        expect(resolver.getOfferPriceAttributeId(), equals(1048));
      },
    );

    test('getAreaAttributeId() корректно находит атрибут площади', () {
      final resolver = AttributeResolver(category2Attributes);
      expect(resolver.getAreaAttributeId(), equals(1127));
    });

    test('getRoomsAttributeId() корректно находит атрибут комнат', () {
      final resolver = AttributeResolver(category2Attributes);
      expect(resolver.getRoomsAttributeId(), equals(6));
    });

    test('getSellerTypeAttributeId() корректно находит тип продавца', () {
      final resolver = AttributeResolver(category2Attributes);
      expect(resolver.getSellerTypeAttributeId(), equals(19));
    });

    test('getRequiredAttributes() возвращает только обязательные атрибуты', () {
      final resolver = AttributeResolver(category2Attributes);
      final required = resolver.getRequiredAttributes();

      expect(required.length, equals(3)); // 6, 1048, 1127
      expect(required.every((a) => a.isRequired), isTrue);
    });

    test('getHiddenAttributes() возвращает только скрытые атрибуты', () {
      final resolver = AttributeResolver(category2Attributes);
      final hidden = resolver.getHiddenAttributes();

      expect(hidden.length, equals(1));
      expect(hidden.first.id, equals(1048));
    });

    test('getRangeAttributes() возвращает только атрибуты с диапазоном', () {
      final resolver = AttributeResolver(category2Attributes);
      final ranges = resolver.getRangeAttributes();

      expect(ranges.length, equals(1));
      expect(ranges.first.id, equals(1127));
    });

    test(
      'getMultipleSelectionAttributes() возвращает множественные выборы',
      () {
        final resolver = AttributeResolver(category2Attributes);
        final multiple = resolver.getMultipleSelectionAttributes();

        expect(multiple.length, equals(2)); // 6, 19
        expect(multiple.every((a) => a.isMultiple), isTrue);
      },
    );

    test('getAttributeById() возвращает атрибут по ID', () {
      final resolver = AttributeResolver(category2Attributes);

      expect(resolver.getAttributeById(6)?.title, equals('Количество комнат'));
      expect(resolver.getAttributeById(9999), isNull);
    });

    test('Сравнение работы старого (hardcoded) vs нового (dynamic) подхода', () {
      // СТАРЫЙ ПОДХОД:
      // switch (categoryId) {
      //   case 2:
      //     return 1048; // "Вам предложат цену"
      //   case 3:
      //     return 1050; // "Вам предложат цену" (ДРУГОЙ ID!)
      //   case 5:
      //     return 1051;
      // }
      // Проблема: При добавлении новой категории нужно обновлять код вручную
      // и помнить правильные ID

      // НОВЫЙ ПОДХОД:
      final resolver = AttributeResolver(category2Attributes);
      final offerId = resolver.getOfferPriceAttributeId();

      // Работает для ЛЮБОЙ категории, как только загружены атрибуты из API
      expect(offerId, equals(1048));

      // Это автоматически работает для категории 3 (ID 1050), 5 (ID 1051) и т.д.
      // потому что мы ищем по названию/признакам, а не по ID
    });

    test('Обработка пустого списка атрибутов', () {
      final resolver = AttributeResolver([]);

      expect(resolver.getOfferPriceAttributeId(), isNull);
      expect(resolver.getAreaAttributeId(), isNull);
      expect(resolver.getRoomsAttributeId(), isNull);
      expect(resolver.getRequiredAttributes().length, equals(0));
    });

    test('Обработка дублирующихся атрибутов (возвращает первый)', () {
      // Иногда API может вернуть дублирующиеся атрибуты
      final attributes = [
        const Attribute(id: 1, title: 'Тест', order: 1),
        const Attribute(id: 2, title: 'Тест', order: 2),
      ];
      final resolver = AttributeResolver(attributes);

      // findAttributeIdByName вернёт первый найденный
      final result = resolver.findAttributeIdByName('Тест');
      expect(result, equals(1));
    });
  });
}
