class CreateAdvertRequest {
  final String name;
  final String description;
  final String price;
  final int categoryId;
  final int regionId;
  final Map<String, dynamic> address;
  final Map<String, dynamic> attributes;
  final Map<String, dynamic> contacts;
  final bool isAutoRenew;

  CreateAdvertRequest({
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.regionId,
    required this.address,
    required this.attributes,
    required this.contacts,
    required this.isAutoRenew,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'region_id': regionId,
      'address': address,
      'attributes': attributes,
      'contacts': contacts,
      'is_auto_renew': isAutoRenew,
    };
  }
}
