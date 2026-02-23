import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/models/filter_models.dart';

void main() {
  group('JSON Parsing Tests - Verifying @JsonKey mappings', () {
    test(
      'Parse field "Только с доставкой" with is_title_hidden and styleSingle',
      () {
        // Simulating API response for "Только с доставкой" field
        final json = {
          'id': 2462,
          'title': 'Только с доставкой',
          'is_filter': true,
          'is_range': false,
          'is_multiple': false,
          'is_hidden': false,
          'is_required': false,
          'is_title_hidden': true,
          'is_special_design': false,
          'is_popup': false,
          'style': 'I',
          'style_single': 'I',
          'data_type': 'integer',
          'order': 1,
          'values': [
            {'id': 1, 'value': 'Только с доставкой', 'order': 0},
          ],
        };

        // Parse the JSON
        final attribute = Attribute.fromJson(json);

        // Verify the parsing
        print('=== Field: "Только с доставкой" ===');
        print('ID: ${attribute.id}');
        print('Title: ${attribute.title}');
        print('is_title_hidden: ${attribute.isTitleHidden} (should be true)');
        print('is_multiple: ${attribute.isMultiple} (should be false)');
        print('style: ${attribute.style}');
        print('styleSingle: ${attribute.styleSingle}');
        print('values.length: ${attribute.values.length}');
        print(
          'values[0].value: ${attribute.values.isNotEmpty ? attribute.values[0].value : 'N/A'}',
        );

        // Assertions
        expect(attribute.id, equals(2462));
        expect(attribute.title, equals('Только с доставкой'));
        expect(
          attribute.isTitleHidden,
          isTrue,
          reason: 'is_title_hidden should be true',
        );
        expect(
          attribute.isMultiple,
          isFalse,
          reason: 'is_multiple should be false',
        );
        expect(attribute.style, equals('I'));
        expect(attribute.styleSingle, equals('I'));
        expect(attribute.values, isNotEmpty);
        expect(attribute.values[0].value, equals('Только с доставкой'));

        print('\n✅ All assertions passed!');
      },
    );

    test('Parse field "Оплата" with is_multiple and is_special_design', () {
      // Simulating API response for "Оплата" field
      final json = {
        'id': 2461,
        'title': 'Оплата',
        'is_filter': true,
        'is_range': false,
        'is_multiple': true,
        'is_hidden': false,
        'is_required': false,
        'is_title_hidden': false,
        'is_special_design': true,
        'is_popup': false,
        'style': 'C1',
        'style_single': 'C1',
        'data_type': 'integer',
        'order': 0,
        'values': [
          {'id': 1, 'value': 'За месяц', 'order': 0},
          {'id': 2, 'value': 'За час', 'order': 1},
        ],
      };

      // Parse the JSON
      final attribute = Attribute.fromJson(json);

      // Verify the parsing
      print('\n=== Field: "Оплата" ===');
      print('ID: ${attribute.id}');
      print('Title: ${attribute.title}');
      print('is_multiple: ${attribute.isMultiple} (should be true)');
      print('is_special_design: ${attribute.isSpecialDesign} (should be true)');
      print('style: ${attribute.style}');
      print('values.length: ${attribute.values.length}');
      print('values: ${attribute.values.map((v) => v.value).toList()}');

      // Assertions
      expect(attribute.id, equals(2461));
      expect(
        attribute.isMultiple,
        isTrue,
        reason: 'is_multiple should be true after JSON parsing fix',
      );
      expect(
        attribute.isSpecialDesign,
        isTrue,
        reason: 'is_special_design should be true after JSON parsing fix',
      );
      expect(attribute.style, equals('C1'));
      expect(attribute.values.length, equals(2));

      print('\n✅ All assertions passed!');
    });

    test('Verify snake_case to camelCase conversion for all boolean flags', () {
      final json = {
        'id': 1,
        'title': 'Test Field',
        'is_filter': true,
        'is_range': true,
        'is_multiple': true,
        'is_hidden': true,
        'is_required': true,
        'is_title_hidden': true,
        'is_special_design': true,
        'is_popup': true,
        'style': 'A',
        'style_single': 'B',
        'data_type': 'string',
        'order': 0,
        'values': [],
      };

      final attribute = Attribute.fromJson(json);

      print('\n=== All Boolean Flag Conversions ===');
      print('isFilter: ${attribute.isFilter} (from is_filter)');
      print('isRange: ${attribute.isRange} (from is_range)');
      print('isMultiple: ${attribute.isMultiple} (from is_multiple)');
      print('isHidden: ${attribute.isHidden} (from is_hidden)');
      print('isRequired: ${attribute.isRequired} (from is_required)');
      print('isTitleHidden: ${attribute.isTitleHidden} (from is_title_hidden)');
      print(
        'isSpecialDesign: ${attribute.isSpecialDesign} (from is_special_design)',
      );
      print('isPopup: ${attribute.isPopup} (from is_popup)');
      print('styleSingle: ${attribute.styleSingle} (from style_single)');

      // All should be true
      expect(attribute.isFilter, isTrue);
      expect(attribute.isRange, isTrue);
      expect(attribute.isMultiple, isTrue);
      expect(attribute.isHidden, isTrue);
      expect(attribute.isRequired, isTrue);
      expect(attribute.isTitleHidden, isTrue);
      expect(attribute.isSpecialDesign, isTrue);
      expect(attribute.isPopup, isTrue);

      print('\n✅ All snake_case fields converted correctly!');
    });
  });
}
