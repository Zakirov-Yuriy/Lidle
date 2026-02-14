import 'package:freezed_annotation/freezed_annotation.dart';

part 'filter_models.freezed.dart';
part 'filter_models.g.dart';

@freezed
class Attribute with _$Attribute {
  const factory Attribute({
    required int id,
    @Default('') String title,
    @Default(false) bool isFilter,
    @Default(false) bool isRange,
    @Default(false) bool isMultiple,
    @Default(false) bool isHidden,
    @Default(false) bool isRequired,
    @Default(false) bool isTitleHidden,
    @Default(false) bool isSpecialDesign,
    @Default(false) bool isMaxValue,
    dynamic maxValue,
    String? vmText,
    String? dataType,
    @Default('') String style,
    required int order,
    @Default([]) List<Value> values,
  }) = _Attribute;

  factory Attribute.fromJson(Map<String, dynamic> json) =>
      _$AttributeFromJson(json);
}

@freezed
class Value with _$Value {
  const factory Value({
    required int id,
    @Default('') String value,
    int? order,
    int? maxValue,
  }) = _Value;

  factory Value.fromJson(Map<String, dynamic> json) => _$ValueFromJson(json);
}

@freezed
class MetaFiltersResponse with _$MetaFiltersResponse {
  const factory MetaFiltersResponse({
    required List<dynamic> sort,
    required List<Attribute> filters,
  }) = _MetaFiltersResponse;

  factory MetaFiltersResponse.fromJson(Map<String, dynamic> json) {
    // Manually parse without relying on generated code due to type casting issues
    print('📦 Parsing MetaFiltersResponse from JSON');
    try {
      final sortList = json['sort'] as List<dynamic>?;
      print('   ✅ sort: ${sortList?.length ?? 0} items');

      final filtersList = json['filters'] as List<dynamic>?;
      final parsedFilters = <Attribute>[];
      if (filtersList != null) {
        for (int i = 0; i < filtersList.length; i++) {
          try {
            final filterJson = filtersList[i] as Map<String, dynamic>;
            final attr = Attribute.fromJson(filterJson);
            parsedFilters.add(attr);
          } catch (e) {
            print('   ⚠️ Failed to parse filter at index $i: $e');
          }
        }
      }
      print('   ✅ filters: ${parsedFilters.length} parsed');

      return MetaFiltersResponse(sort: sortList ?? [], filters: parsedFilters);
    } catch (e) {
      print('❌ Error parsing MetaFiltersResponse: $e');
      // Ultimate fallback
      return MetaFiltersResponse(sort: [], filters: []);
    }
  }
}
