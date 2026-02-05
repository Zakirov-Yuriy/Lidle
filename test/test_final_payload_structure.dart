/// Final test payload for creating advert with correct attribute structure
///
/// Key insights:
/// 1. address.region_id must use region.id (sub-region), not main_region.id
/// 2. Attribute 1048 (Вам предложат цену) is boolean type, goes at top-level
/// 3. Attribute 1127 (Общая площадь) is range type, goes in attributes.values

void main() {
  final correctPayload = {
    "region_id": 1, // main_region.id
    "address": {
      "region_id": 13, // region.id (sub-region Donetsk), NOT main_region
      "city_id": 70, // Мариуполь
      "street_id": 9199, // ул. Артёма
      "building": "123",
    },
    "category_id": 2,
    "title": "Квартира в центре города",
    "description": "Уютная квартира на улице Артёма",
    "price": "500000",
    "phone_id": 21,
    "email_id": 18,

    // ✅ IMPORTANT: attribute_1048 goes at TOP-LEVEL (not in attributes!)
    "attribute_1048": true, // Вам предложат цену (boolean type)

    "attributes": {
      "value_selected": [
        42, // Attribute 6 - 3 комнаты
        174, // Attribute 19 - Частное лицо
      ],
      "values": {
        // Attribute 1040 - Этаж (range, integer)
        "1040": {"value": 4, "max_value": 5},
        // Attribute 1127 - Общая площадь (range, numeric) - REQUIRED
        "1127": {"value": 50, "max_value": 100},
      },
    },
    "is_auto_renew": true,
  };

  print('Correct payload structure:');
  print('✅ region_id: 1 (main_region.id)');
  print('✅ address.region_id: 13 (region.id, sub-region)');
  print('✅ attribute_1048: true (top-level boolean field)');
  print('✅ attributes.value_selected: [42 (rooms=3), 174 (private)]');
  print('✅ attributes.values[1040]: {value: 4, max_value: 5} (floor range)');
  print('✅ attributes.values[1127]: {value: 50, max_value: 100} (area range)');

  print('\nAPI should return: 201 Created');
  print('Expected message: "Объявление успешно создано"');
}
