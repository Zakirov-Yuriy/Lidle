import 'dart:convert';

void main() {
  // Simulate what should be sent to API
  print('=== TESTING ATTRIBUTE 1048 PAYLOAD ===\n');

  // This is what SHOULD be created by _collectFormData()
  final Map<String, dynamic> attributes = {
    'value_selected': [42, 174], // Комнаты и другие выборы
    'values': <String, dynamic>{
      '1040': {'value': 4, 'max_value': 5}, // Этаж
      '1127': {'value': 50, 'max_value': 100}, // Общая площадь
      '1048': true, // Вам предложат цену - BOOLEAN, not Map!
    },
  };

  print('✅ Attributes structure:');
  print(JsonEncoder.withIndent('  ').convert({'attributes': attributes}));

  final values = attributes['values'] as Map<String, dynamic>;
  print('\n✅ Type of 1048 value: ${values['1048'].runtimeType}');
  print('✅ Type of 1040 value: ${values['1040'].runtimeType}');
  print('✅ Type of 1127 value: ${values['1127'].runtimeType}');

  // Verify JSON encoding works
  final json = {
    'name': 'Test Ad',
    'price': 1000,
    'category_id': 1,
    'address': 'Test Address',
    'attributes': attributes,
    'contacts': {'phone': '+1234567890'},
    'is_auto_renew': false,
  };

  print('\n✅ Full JSON payload:');
  print(JsonEncoder.withIndent('  ').convert(json));

  // Test various scenarios
  print('\n=== SCENARIO ANALYSIS ===\n');

  print('Scenario 1: 1048 as boolean true');
  print('  Value: true, Type: ${true.runtimeType}');
  print('  JSON: ${jsonEncode(true)}');

  print('\nScenario 2: 1048 as string "true"');
  print('  Value: "true", Type: ${"true".runtimeType}');
  print('  JSON: ${jsonEncode("true")}');

  print('\nScenario 3: 1048 as 1 (integer)');
  print('  Value: 1, Type: ${1.runtimeType}');
  print('  JSON: ${jsonEncode(1)}');

  print('\nScenario 4: 1048 as Map');
  print('  Value: {}, Type: {}.runtimeType');
  print('  JSON: ${jsonEncode({})}');

  print('\n=== EXPECTED API FORMAT ===\n');
  print('''
API expects "attributes" to contain:
{
  "value_selected": [42, 174],  // Array of VALUE IDs
  "values": {
    "1040": {
      "value": 4,           // Min value for range
      "max_value": 5        // Max value for range
    },
    "1127": {
      "value": 50,          // Min area
      "max_value": 100      // Max area
    },
    "1048": true            // BOOLEAN - not a Map!
  }
}

CRITICAL: 1048 must be a BOOLEAN (true/false), NOT a Map!
''');
}
