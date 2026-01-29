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
    required Map<String, String> sort,
    required List<Attribute> filters,
  }) = _MetaFiltersResponse;

  factory MetaFiltersResponse.fromJson(Map<String, dynamic> json) =>
      _$MetaFiltersResponseFromJson(json['data']);
}
