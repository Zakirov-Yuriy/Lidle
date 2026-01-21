import 'package:freezed_annotation/freezed_annotation.dart';

part 'filter_models.freezed.dart';
part 'filter_models.g.dart';

@freezed
class Attribute with _$Attribute {
  const factory Attribute({
    required int id,
    @JsonKey(defaultValue: '') @Default('') String title,
    @JsonKey(defaultValue: false) @Default(false) bool isFilter,
    @JsonKey(defaultValue: false) @Default(false) bool isRange,
    @JsonKey(defaultValue: false) @Default(false) bool isMultiple,
    @JsonKey(defaultValue: false) @Default(false) bool isHidden,
    @JsonKey(defaultValue: false) @Default(false) bool isRequired,
    @JsonKey(defaultValue: false) @Default(false) bool isTitleHidden,
    @JsonKey(defaultValue: false) @Default(false) bool isSpecialDesign,
    @JsonKey(defaultValue: false) @Default(false) bool isMaxValue,
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
    @JsonKey(defaultValue: '') @Default('') String value,
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
