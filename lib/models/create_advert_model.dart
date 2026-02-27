class CreateAdvertRequest {
  final String name;
  final String description;
  final String price;
  final int categoryId;
  final int? regionId;
  final Map<String, dynamic> address;
  final Map<String, dynamic> attributes;
  final Map<String, dynamic> contacts;
  final bool isAutoRenew;
  final List<String> images; // URLs of uploaded images

  CreateAdvertRequest({
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    this.regionId,
    required this.address,
    required this.attributes,
    required this.contacts,
    required this.isAutoRenew,
    this.images = const [],
  });

  Map<String, dynamic> toJson() {
    // print('📦 CreateAdvertRequest.toJson() called');
    // print('   Input attributes keys: ${attributes.keys.toList()}');

    // Build attributes according to API format:
    // {
    //   "value_selected": [42, 174, ...],  // VALUE IDs for multiple-choice attributes
    //   "values": {                         // For range, text, and boolean attributes
    //     "1040": {value: 4, max_value: 5},     // Range: Floor
    //     "1127": {value: 50, max_value: 100}, // Range: Total area
    //     "1048": {value: 1},                  // Boolean: Price offer acceptance (REQUIRED!)
    //     "1039": "Building name"               // Text field: Building name
    //   }
    // }

    final flatAttributes = <String, dynamic>{};

    // Always include value_selected if it exists
    if (attributes.containsKey('value_selected')) {
      flatAttributes['value_selected'] = attributes['value_selected'];
      // print('   ✅ Copied value_selected: ${attributes['value_selected']}');
    }

    // Process values map - KEEP 1048 in values (API requires it there!)
    if (attributes.containsKey('values')) {
      final values = attributes['values'] as Map<String, dynamic>?;
      if (values != null && values.isNotEmpty) {
        // Keep all values including 1048
        flatAttributes['values'] = Map<String, dynamic>.from(values);
        // print();
      }
    }

    // print('   📤 Processed attributes: $flatAttributes');

    // Build final JSON
    final json = {
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      if (regionId != null) 'region_id': regionId,
      'address': address,
      'attributes': flatAttributes,
      'contacts': contacts,
      'is_auto_renew': isAutoRenew,
      if (images.isNotEmpty) 'images': images,
    };

    // NOTE: attribute 1048 should stay in values as {'value': 1}
    // API expects: attributes.values['1048'] = {'value': 1}
    // NOT at top-level

    // print();
    // print('   📤 JSON ready to send');
    return json;
  }
}


